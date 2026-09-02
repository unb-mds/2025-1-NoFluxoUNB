// ============================================================================
// DRAFT — Edge Function push-dispatch
// ============================================================================
// STATUS: RASCUNHO. Revisar antes de deployar.
//
// O QUE FAZ
//   Recebe o payload de Database Webhook do Supabase disparado por INSERT na
//   tabela `notificacoes` (o INSERT é feito pelo trigger notificar_vaga_
//   disponivel quando abre vaga em `turmas`), busca os device_tokens do
//   usuário da notificação e envia push via FCM HTTP v1 para cada aparelho.
//
// SETUP COMPLETO (fazer nesta ordem)
//   1. Aplicar a migration DRAFT_001_device_tokens.sql (revisada).
//   2. Criar projeto no Firebase e baixar o JSON da service account:
//      Firebase Console → Configurações do projeto → Contas de serviço →
//      "Gerar nova chave privada".
//   3. Definir os secrets da função (o JSON inteiro em uma variável):
//        supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
//        # opcional, mas recomendado — valida a origem do webhook:
//        supabase secrets set PUSH_WEBHOOK_SECRET="algum-segredo-forte"
//      (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY já são injetados
//       automaticamente pelo runtime de Edge Functions.)
//   4. Deploy:
//        supabase functions deploy push-dispatch --no-verify-jwt
//      (--no-verify-jwt porque quem chama é o webhook do banco, não um
//       usuário logado; a autenticação é feita pelo PUSH_WEBHOOK_SECRET.)
//   5. Criar o webhook no dashboard:
//      Database → Webhooks → Create webhook
//        - Table: public.notificacoes
//        - Events: INSERT
//        - Type: Supabase Edge Function → push-dispatch
//        - HTTP Headers: x-webhook-secret = <mesmo valor de PUSH_WEBHOOK_SECRET>
//   6. Testar ponta a ponta: inserir uma linha em `notificacoes` na mão
//      (ver docs/PUSH_SETUP.md) e conferir o push no aparelho.
//
// FORMATO DO PAYLOAD DO WEBHOOK (Database Webhook, INSERT):
//   { "type": "INSERT", "table": "notificacoes", "schema": "public",
//     "record": { id_notificacao, id_user, tipo, titulo, mensagem,
//                 metadata: { codigo_materia, turma, ano_periodo,
//                             vagas_sobrando, ... }, ... },
//     "old_record": null }
//
// Sem dependências externas: usa apenas fetch e crypto.subtle do Deno
// (o access token OAuth2 do Google é gerado assinando um JWT RS256 na mão).
// ============================================================================

// ---------------------------------------------------------------------------
// Tipos
// ---------------------------------------------------------------------------

interface WebhookPayload {
  type: string;
  table?: string;
  record?: NotificacaoRecord;
}

interface NotificacaoRecord {
  id_notificacao: number;
  id_user: number;
  tipo: string;
  titulo: string;
  mensagem: string;
  metadata?: Record<string, unknown> | null;
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri: string;
}

interface DeviceTokenRow {
  token: string;
  platform: string | null;
}

// ---------------------------------------------------------------------------
// OAuth2: gera access token do Google assinando JWT RS256 com crypto.subtle
// ---------------------------------------------------------------------------

const ESCOPO_FCM = "https://www.googleapis.com/auth/firebase.messaging";

// Cache do token em escopo de módulo (a isolate pode atender vários requests).
let tokenCacheado: { accessToken: string; expiraEm: number } | null = null;

/** Codifica bytes/string em base64url (sem padding). */
function base64url(dados: Uint8Array | string): string {
  const bytes = typeof dados === "string"
    ? new TextEncoder().encode(dados)
    : dados;
  let binario = "";
  for (const b of bytes) binario += String.fromCharCode(b);
  return btoa(binario).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Converte a private_key PEM (PKCS#8) da service account em CryptoKey. */
async function importarChavePrivada(pem: string): Promise<CryptoKey> {
  const corpo = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(corpo), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/** Obtém (com cache) um access token OAuth2 para a API do FCM. */
async function obterAccessToken(sa: ServiceAccount): Promise<string> {
  const agora = Math.floor(Date.now() / 1000);
  // Margem de 60s para não usar token à beira de expirar.
  if (tokenCacheado && tokenCacheado.expiraEm - 60 > agora) {
    return tokenCacheado.accessToken;
  }

  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: ESCOPO_FCM,
    aud: sa.token_uri,
    iat: agora,
    exp: agora + 3600,
  }));
  const conteudo = `${header}.${claims}`;

  const chave = await importarChavePrivada(sa.private_key);
  const assinatura = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    chave,
    new TextEncoder().encode(conteudo),
  );
  const jwt = `${conteudo}.${base64url(new Uint8Array(assinatura))}`;

  const resp = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!resp.ok) {
    throw new Error(`Falha ao obter access token do Google: ${resp.status} ${await resp.text()}`);
  }
  const json = await resp.json();
  tokenCacheado = {
    accessToken: json.access_token,
    expiraEm: agora + (json.expires_in ?? 3600),
  };
  return tokenCacheado.accessToken;
}

// ---------------------------------------------------------------------------
// Supabase REST (service role) — sem client lib, só fetch
// ---------------------------------------------------------------------------

function headersServiceRole(): HeadersInit {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json",
  };
}

/** Busca os tokens de push de um usuário. */
async function buscarDeviceTokens(idUser: number): Promise<DeviceTokenRow[]> {
  const url = `${Deno.env.get("SUPABASE_URL")}/rest/v1/device_tokens` +
    `?id_user=eq.${idUser}&select=token,platform`;
  const resp = await fetch(url, { headers: headersServiceRole() });
  if (!resp.ok) {
    throw new Error(`Falha ao buscar device_tokens: ${resp.status} ${await resp.text()}`);
  }
  return await resp.json();
}

/** Remove um token inválido/expirado da tabela. */
async function removerDeviceToken(token: string): Promise<void> {
  const url = `${Deno.env.get("SUPABASE_URL")}/rest/v1/device_tokens` +
    `?token=eq.${encodeURIComponent(token)}`;
  const resp = await fetch(url, { method: "DELETE", headers: headersServiceRole() });
  if (!resp.ok) {
    console.error(`Falha ao remover token inválido: ${resp.status} ${await resp.text()}`);
  }
}

// ---------------------------------------------------------------------------
// Montagem da mensagem FCM
// ---------------------------------------------------------------------------

/**
 * Monta o campo `data` da mensagem FCM a partir do record da notificação.
 * FCM exige que todos os valores de `data` sejam strings.
 */
function montarData(record: NotificacaoRecord): Record<string, string> {
  const metadata = record.metadata ?? {};
  const data: Record<string, string> = {
    tipo: String(record.tipo ?? ""),
    id_notificacao: String(record.id_notificacao ?? ""),
  };
  for (const [chave, valor] of Object.entries(metadata)) {
    if (valor === null || valor === undefined) continue;
    data[chave] = typeof valor === "string" ? valor : JSON.stringify(valor);
  }
  const codigo = metadata["codigo_materia"];
  if (typeof codigo === "string" && codigo.length > 0) {
    data["deep_link"] = `nofluxo://turmas?codigo=${encodeURIComponent(codigo)}`;
  }
  return data;
}

/** Monta o corpo da mensagem FCM HTTP v1 para um token. */
function montarMensagemFcm(
  token: string,
  record: NotificacaoRecord,
): Record<string, unknown> {
  return {
    message: {
      token,
      notification: {
        title: record.titulo,
        body: record.mensagem,
      },
      data: montarData(record),
      android: {
        priority: "high",
        notification: {
          channel_id: "vagas",
        },
      },
      apns: {
        payload: {
          aps: { sound: "default" },
        },
      },
    },
  };
}

/**
 * Envia a mensagem para um token. Retorna "ok", "token_invalido" (deve ser
 * removido da tabela) ou "erro" (falha transitória; mantém o token).
 */
async function enviarParaToken(
  accessToken: string,
  projectId: string,
  token: string,
  record: NotificacaoRecord,
): Promise<"ok" | "token_invalido" | "erro"> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(montarMensagemFcm(token, record)),
  });

  if (resp.ok) return "ok";

  const corpo = await resp.text();
  // Só remove o token quando o ERRO ESTRUTURADO do FCM v1 indicar token morto:
  // error.status NOT_FOUND com errorCode UNREGISTERED (app desinstalado /
  // token expirado) ou INVALID_ARGUMENT com errorCode INVALID_ARGUMENT
  // (token malformado). Matching por substring no corpo seria perigoso:
  // um erro genérico de projeto/config mal feito apagaria tokens VÁLIDOS
  // em massa — qualquer outro erro loga e MANTÉM o token.
  let tokenMorto = false;
  try {
    const erro = JSON.parse(corpo)?.error;
    const detalhes: Array<Record<string, unknown>> = erro?.details ?? [];
    const errorCode = (detalhes.find(
      (d) => String(d["@type"] ?? "").endsWith("google.firebase.fcm.v1.FcmError"),
    ) as { errorCode?: string } | undefined)?.errorCode;
    // INVALID_ARGUMENT também cobre erros de PAYLOAD (mensagem grande demais,
    // chave reservada em data) — apagar tokens nesses casos seria a deleção
    // em massa que queremos evitar. Só é token morto quando o BadRequest
    // aponta especificamente para o campo message.token.
    const violacaoNoToken = detalhes.some(
      (d) =>
        String(d["@type"] ?? "").endsWith("google.rpc.BadRequest") &&
        Array.isArray(d.fieldViolations) &&
        (d.fieldViolations as Array<{ field?: string }>).some((v) =>
          String(v.field ?? "").includes("message.token"),
        ),
    );
    tokenMorto =
      (erro?.status === "NOT_FOUND" && errorCode === "UNREGISTERED") ||
      (erro?.status === "INVALID_ARGUMENT" &&
        errorCode === "INVALID_ARGUMENT" &&
        violacaoNoToken);
  } catch {
    // Corpo não-JSON: não dá para afirmar que o token morreu — mantém.
  }
  if (tokenMorto) {
    console.warn(`Token inválido (${resp.status}): ${corpo.slice(0, 200)}`);
    return "token_invalido";
  }
  console.error(`Erro FCM (${resp.status}): ${corpo.slice(0, 500)}`);
  return "erro";
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  try {
    // Autenticação do webhook — OBRIGATÓRIA. Como o deploy usa
    // --no-verify-jwt (o webhook do Postgres não manda JWT), o secret é a
    // única barreira: sem ele configurado, ou com header errado, a função
    // recusa. Nunca rode esta função sem PUSH_WEBHOOK_SECRET definido.
    const segredoEsperado = Deno.env.get("PUSH_WEBHOOK_SECRET");
    if (!segredoEsperado) {
      console.error(
        "PUSH_WEBHOOK_SECRET não configurado — recusando todas as chamadas.",
      );
      return new Response(JSON.stringify({ error: "Função não configurada" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
    if (req.headers.get("x-webhook-secret") !== segredoEsperado) {
      return new Response(JSON.stringify({ error: "Não autorizado" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const payload: WebhookPayload = await req.json();

    // Só INSERT em notificacoes interessa.
    if (payload.type !== "INSERT" || !payload.record) {
      return new Response(JSON.stringify({ skipped: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const record = payload.record;
    if (!record.id_user) {
      return new Response(JSON.stringify({ skipped: true, motivo: "sem id_user" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!saJson) {
      throw new Error("Secret FIREBASE_SERVICE_ACCOUNT não configurado");
    }
    const sa: ServiceAccount = JSON.parse(saJson);

    const tokens = await buscarDeviceTokens(record.id_user);
    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ enviados: 0, motivo: "usuário sem device_tokens" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const accessToken = await obterAccessToken(sa);

    // Envios em paralelo: um await por token dobraria o wall-time (cobrado)
    // linearmente com o nº de aparelhos do usuário.
    let enviados = 0;
    let removidos = 0;
    let erros = 0;
    const resultados = await Promise.allSettled(
      tokens.map(async (linha) => {
        const resultado = await enviarParaToken(
          accessToken,
          sa.project_id,
          linha.token,
          record,
        );
        if (resultado === "token_invalido") {
          await removerDeviceToken(linha.token);
        }
        return resultado;
      }),
    );
    for (const r of resultados) {
      if (r.status !== "fulfilled") erros++;
      else if (r.value === "ok") enviados++;
      else if (r.value === "token_invalido") removidos++;
      else erros++;
    }

    return new Response(JSON.stringify({ enviados, removidos, erros }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (erro) {
    console.error("push-dispatch falhou:", erro);
    return new Response(JSON.stringify({ error: String(erro) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
