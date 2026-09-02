/// Parser dos marcadores da resposta do Darcy — porte fiel do
/// `parseMessage` de `no_fluxo_frontend_svelte/src/lib/components/chat/
/// ChatPanel.svelte` (fonte da verdade do formato).
///
/// O reply do backend (`POST /chat/send`) vem como texto com marcadores
/// inline que a UI transforma em widgets:
///  - `**negrito**` → [SegmentoNegrito];
///  - códigos de matéria (`CIC0007`) → [SegmentoBadge] tocável;
///  - `[TURMA|turma|professor|horario|local|vagas|periodo?]` → [BlocoTurma];
///  - `[BOTAO|Label|mensagem?]` → [BlocoBotoes] (consecutivos são agrupados);
///  - `[MONTAR_GRADE|...]` → reconhecido e IGNORADO no v1 (o app ainda não
///    monta grade a partir do chat).
///
/// Função pura: string → lista de blocos tipados. Marcador malformado não
/// casa com o regex e degrada naturalmente para texto cru.
library;

/// Pedaço inline de uma bolha de texto.
sealed class SegmentoChat {
  const SegmentoChat();
}

/// Texto corrido.
class SegmentoTexto extends SegmentoChat {
  final String valor;

  const SegmentoTexto(this.valor);
}

/// Trecho em negrito (`**...**`).
class SegmentoNegrito extends SegmentoChat {
  final String valor;

  const SegmentoNegrito(this.valor);
}

/// Código de matéria (ex.: `CIC0007`) — vira badge tocável que abre a busca
/// de turmas.
class SegmentoBadge extends SegmentoChat {
  final String codigo;

  const SegmentoBadge(this.codigo);
}

/// Bloco de alto nível da resposta (a lista renderizada na coluna do Darcy).
sealed class BlocoChat {
  const BlocoChat();
}

/// Bolha de texto com segmentos inline.
class BlocoBolha extends BlocoChat {
  final List<SegmentoChat> segmentos;

  const BlocoBolha(this.segmentos);
}

/// Dados de um card `[TURMA|...]`.
class TurmaChat {
  final String turma;
  final String professor;
  final String horario;
  final String local;
  final String vagas;
  final String? periodo;

  const TurmaChat({
    required this.turma,
    required this.professor,
    required this.horario,
    required this.local,
    required this.vagas,
    this.periodo,
  });
}

/// Card de turma sugerida pelo Darcy.
class BlocoTurma extends BlocoChat {
  final TurmaChat turma;

  const BlocoTurma(this.turma);
}

/// Ação rápida `[BOTAO|Label|mensagem?]`: tocar envia [mensagem] ao chat.
class BotaoChat {
  final String label;
  final String mensagem;

  const BotaoChat({required this.label, required this.mensagem});
}

/// Grupo de botões consecutivos (renderizados lado a lado, como no site).
class BlocoBotoes extends BlocoChat {
  final List<BotaoChat> botoes;

  const BlocoBotoes(this.botoes);
}

/// Mesmo regex do site (ChatPanel.svelte), grupo a grupo:
///  1 badge | 2..8 turma | 9..11 botão | 12..13 negrito | 14..15 montar grade.
final RegExp _marcadores = RegExp(
  r'(\b[A-Z]{3,4}\d{4}\b)'
  r'|(\[TURMA\|([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)\|([^|\]]+)(?:\|([^\]]+))?\])'
  r'|(\[BOTAO\|([^|\]]+)(?:\|([^\]]+))?\])'
  r'|(\*\*([^*\n]+)\*\*)'
  r'|(\[MONTAR_GRADE\|([^\]]+)\])',
);

final RegExp _linhasEmBranco = RegExp(r'\n{3,}');
final RegExp _bullet = RegExp(r'^[ \t]*[-*]\s+', multiLine: true);
final RegExp _listaNumerada = RegExp(r'^[ \t]*(\d+)[.)]\s+', multiLine: true);
final RegExp _camelCase = RegExp(r'([a-z])([A-Z])');

/// Converte o reply do Darcy na lista de blocos tipados que a UI renderiza.
List<BlocoChat> parseReply(String reply) {
  // Tipografia (igual ao site): bullets de verdade e linhas em branco
  // colapsadas — o texto cru do modelo é corrido demais de ler.
  final texto = reply
      .replaceAll(_linhasEmBranco, '\n\n')
      .replaceAllMapped(_bullet, (_) => '•  ')
      .replaceAllMapped(_listaNumerada, (m) => '${m[1]}.  ');

  final blocos = <BlocoChat>[];
  var bolhaAtual = <SegmentoChat>[];

  void flushBolha() {
    if (bolhaAtual.isEmpty) return;
    final temConteudo = bolhaAtual.any(
      (s) => switch (s) {
        SegmentoBadge() || SegmentoNegrito() => true,
        SegmentoTexto(:final valor) => valor.trim().isNotEmpty,
      },
    );
    if (temConteudo) blocos.add(BlocoBolha(bolhaAtual));
    bolhaAtual = <SegmentoChat>[];
  }

  var ultimoIndice = 0;
  for (final match in _marcadores.allMatches(texto)) {
    if (match.start > ultimoIndice) {
      bolhaAtual.add(SegmentoTexto(texto.substring(ultimoIndice, match.start)));
    }

    if (match[1] != null) {
      bolhaAtual.add(SegmentoBadge(match[1]!));
    } else if (match[2] != null) {
      flushBolha();
      blocos.add(
        BlocoTurma(
          TurmaChat(
            turma: match[3]!.trim(),
            professor: match[4]!.trim(),
            horario: match[5]!.trim(),
            local: match[6]!.trim(),
            vagas: match[7]!.trim(),
            periodo: match[8]?.trim(),
          ),
        ),
      );
    } else if (match[9] != null) {
      flushBolha();
      blocos.add(
        BlocoBotoes([
          BotaoChat(
            label: match[10]!.trim().replaceAllMapped(
              _camelCase,
              (m) => '${m[1]} ${m[2]}',
            ),
            mensagem: match[11]?.trim() ?? match[10]!.trim(),
          ),
        ]),
      );
    } else if (match[12] != null) {
      bolhaAtual.add(SegmentoNegrito(match[13]!));
    } else if (match[14] != null) {
      // [MONTAR_GRADE|...]: reconhecido para não vazar como texto cru, mas
      // ignorado no v1 — o app ainda não tem montagem de grade via chat.
      flushBolha();
    }

    ultimoIndice = match.end;
  }

  if (ultimoIndice < texto.length) {
    bolhaAtual.add(SegmentoTexto(texto.substring(ultimoIndice)));
  }
  flushBolha();

  // Agrupa botões consecutivos para ficarem lado a lado (como no site).
  final agrupados = <BlocoChat>[];
  for (final bloco in blocos) {
    final anterior = agrupados.isEmpty ? null : agrupados.last;
    if (bloco is BlocoBotoes && anterior is BlocoBotoes) {
      agrupados[agrupados.length - 1] = BlocoBotoes([
        ...anterior.botoes,
        ...bloco.botoes,
      ]);
    } else {
      agrupados.add(bloco);
    }
  }
  return agrupados;
}
