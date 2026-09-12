#!/usr/bin/env node
/**
 * audit_aproveitamento.mjs — Auditoria READ-ONLY do impacto dos bugs de
 * aproveitamento (CUMP sem período) e "Matriculado em Equivalente" nos dados
 * persistidos dos usuários (tabela dados_users.fluxograma_atual).
 *
 * CONTEXTO (o que está persistido — ver relatório da investigação):
 *   - dados_users.fluxograma_atual (text/JSON): resultado FINAL do casamento
 *     (uma entrada POR LINHA do extrato do SIGAA que sobreviveu ao parser:
 *     codigo, status [APR/REP/TRANC/MATR/CUMP/DISP/...], mencao, ano_periodo,
 *     tipo_dado, codigo_equivalente, ...). Formato definido em
 *     no_fluxo_frontend_svelte/src/lib/factories/index.ts (dadosMateriaToJson).
 *   - O PDF bruto e o extracted_data do parser NÃO são persistidos. Logo:
 *       (a) Um CUMP descartado pelo parser é INVISÍVEL aqui — auditamos por
 *           PROXY: matérias cujo único registro é REP/REPF/REPMF/TRANC/CANC
 *           (nunca aprovadas nem MATR) em usuários que têm sinal de
 *           aproveitamento, e a população geral exposta (qualquer CUMP/DISP).
 *       (b) "Matriculado em Equivalente" é auditável DIRETAMENTE: entrada com
 *           status MATR num código Y que consta na expressão de equivalência
 *           de uma obrigatória X não aprovada → X aparece vermelha (se X tem
 *           REP) ou disponível/bloqueada (se X não tem registro) em vez de
 *           roxa (matriculado). Espelha determineSubjectStatus()
 *           (no_fluxo_frontend_svelte/src/lib/types/materia.ts:94) +
 *           currentCodes/failedCodes (fluxograma.store.svelte.ts:292-310).
 *
 * SEGURANÇA:
 *   - Somente SELECTs (nenhum insert/update/delete/rpc de escrita).
 *   - Exige AUDIT_CONFIRM=1 para rodar (evita execução acidental em produção).
 *   - Saída usa apenas id_user e códigos de matéria (sem nome/e-mail).
 *
 * USO (quando autorizado):
 *   cd /Users/vitormarconi/Documents/GitHub/2025-1-NoFluxoUNB/2025-1-NoFluxoUNB
 *   set -a && source no_fluxo_backend/.env && set +a
 *   AUDIT_CONFIRM=1 node scripts/audit_aproveitamento.mjs [--json] [--historicos]
 *
 * Requer: SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY no ambiente (service role
 * necessário para ler dados de todos os usuários — RLS restringe anon/auth).
 * Dependência resolvida de no_fluxo_backend/node_modules via createRequire.
 */

import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendDir = path.resolve(__dirname, '..', 'no_fluxo_backend');
const require = createRequire(path.join(backendDir, 'package.json'));
const { createClient } = require('@supabase/supabase-js');

// ─── Guardas ────────────────────────────────────────────────────────────────
if (process.env.AUDIT_CONFIRM !== '1') {
	console.error(
		'[audit] Recusando executar: defina AUDIT_CONFIRM=1 explicitamente.\n' +
			'[audit] Este script é read-only, mas conecta no banco apontado por SUPABASE_URL.'
	);
	process.exit(2);
}
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!SUPABASE_URL || !SUPABASE_KEY) {
	console.error('[audit] SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY são obrigatórios no ambiente.');
	process.exit(2);
}

const OUT_JSON = process.argv.includes('--json');
const USE_HISTORICOS = process.argv.includes('--historicos');

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
	auth: { persistSession: false }
});

// ─── Espelho da lógica do frontend (types/user.ts:109-130) ──────────────────
const APROVADA_STATUS = new Set(['APR', 'CUMP', 'DISP']);
const REPROVADA_STATUS = new Set(['REP', 'REPF', 'REPMF']);
const NAO_APROVADA_STATUS = new Set(['TRANC', 'MATR', 'CANC', 'REP', 'REPF', 'REPMF']);
const APROVADA_MENCOES = new Set(['SS', 'MM', 'MS']);

function norm(s) {
	return String(s ?? '').trim().toUpperCase();
}
function isAprovada(entry) {
	const status = norm(entry.status ?? '-');
	if (APROVADA_STATUS.has(status)) return true;
	if (NAO_APROVADA_STATUS.has(status)) return false;
	return APROVADA_MENCOES.has(norm(entry.mencao ?? '-')); // fallback legado
}

// ─── Extração de códigos de expressao_logica (espelha
//     no_fluxo_backend/src/controllers/fluxograma_controller.ts:63-83) ──────
const CODE_RE = /[A-Z]{2,}\d{3,}/g;
function codesFromExpressaoLogica(node, out = new Set()) {
	if (node == null) return out;
	if (typeof node === 'string') {
		for (const m of node.toUpperCase().matchAll(CODE_RE)) out.add(m[0]);
		return out;
	}
	if (Array.isArray(node)) {
		for (const c of node) codesFromExpressaoLogica(c, out);
		return out;
	}
	if (typeof node === 'object') {
		if (Array.isArray(node.condicoes)) codesFromExpressaoLogica(node.condicoes, out);
		if (Array.isArray(node.materias)) codesFromExpressaoLogica(node.materias, out);
		for (const k of ['codigo', 'codigo_materia']) {
			if (typeof node[k] === 'string') codesFromExpressaoLogica(node[k], out);
		}
	}
	return out;
}
function codesFromEquivalencia(row) {
	const out = codesFromExpressaoLogica(row.expressao_logica);
	if (out.size === 0 && row.expressao_original) {
		for (const m of String(row.expressao_original).toUpperCase().matchAll(CODE_RE)) out.add(m[0]);
	}
	return out;
}

// ─── Fetch paginado (só SELECT) ─────────────────────────────────────────────
async function fetchAll(table, columns, orderCol) {
	const PAGE = 1000;
	const rows = [];
	for (let from = 0; ; from += PAGE) {
		const { data, error } = await supabase
			.from(table)
			.select(columns)
			.order(orderCol, { ascending: true })
			.range(from, from + PAGE - 1);
		if (error) throw new Error(`select ${table}: ${error.message}`);
		rows.push(...(data ?? []));
		if (!data || data.length < PAGE) break;
	}
	return rows;
}

function parseFluxograma(raw) {
	// dados_users.fluxograma_atual é text (JSON string); historicos é jsonb.
	let obj = raw;
	if (typeof raw === 'string') {
		const t = raw.trim();
		if (!t || t === '{}') return null;
		try {
			obj = JSON.parse(t);
		} catch {
			return null;
		}
	}
	if (obj == null || typeof obj !== 'object') return null;
	const semestres = obj.dados_fluxograma ?? obj.dadosFluxograma;
	if (!Array.isArray(semestres)) return null;
	const entries = [];
	for (const sem of semestres) {
		if (!Array.isArray(sem)) continue;
		for (const m of sem) {
			if (!m || typeof m !== 'object') continue;
			const codigo = norm(m.codigo ?? m.codigoMateria ?? m.codigo_materia);
			if (!codigo) continue;
			entries.push({
				codigo,
				status: norm(m.status ?? '-'),
				mencao: norm(m.mencao ?? '-'),
				ano_periodo: m.ano_periodo ?? m.anoPeriodo ?? null,
				tipo_dado: m.tipo_dado ?? m.tipoDado ?? null
			});
		}
	}
	return { entries, nome_curso: obj.nome_curso ?? obj.nomeCurso ?? null };
}

// ─── Auditoria por usuário ──────────────────────────────────────────────────
function auditUser(entries, equivalencias) {
	const byCode = new Map();
	for (const e of entries) {
		if (!byCode.has(e.codigo)) byCode.set(e.codigo, []);
		byCode.get(e.codigo).push(e);
	}

	const completed = new Set();
	const current = new Set();
	const failed = new Set();
	for (const [codigo, list] of byCode) {
		if (list.some(isAprovada)) completed.add(codigo);
		if (list.some((e) => e.status === 'MATR')) current.add(codigo);
		if (list.some((e) => REPROVADA_STATUS.has(e.status))) failed.add(codigo);
	}

	// (a) Sinais relacionados a aproveitamento (CUMP/DISP)
	const cumpCodes = [...byCode.entries()]
		.filter(([, list]) => list.some((e) => e.status === 'CUMP' || e.status === 'DISP'))
		.map(([c]) => c);
	// CUMP/DISP persistido mas NÃO contado como concluída (não deveria existir;
	// se aparecer, é corrupção/inconsistência de dados persistidos)
	const cumpNaoConcluida = cumpCodes.filter((c) => !completed.has(c));
	// PROXY de CUMP perdido no parser: código só com reprovação/tranc/canc,
	// nunca aprovado nem matriculado (o CUMP sem período teria sido descartado
	// antes de chegar aqui — não dá para provar, só dimensionar o cohort)
	const failedNeverApproved = [...byCode.keys()].filter(
		(c) => failed.has(c) && !completed.has(c) && !current.has(c)
	);

	// (b) "Matriculado em Equivalente" perdido:
	// MATR em Y, e existe equivalência X <- (… Y …) com X não aprovada e sem MATR direto.
	const equivMatrPerdido = [];
	for (const eq of equivalencias) {
		const alvo = eq.codigo_origem;
		if (!alvo || completed.has(alvo) || current.has(alvo)) continue;
		for (const y of eq.codigos_equivalentes) {
			if (y === alvo) continue;
			if (current.has(y)) {
				equivMatrPerdido.push({
					obrigatoria: alvo,
					equivalente_matr: y,
					renderiza_como: failed.has(alvo) ? 'REPROVADA (vermelha)' : 'disponivel/bloqueada',
					id_equivalencia: eq.id_equivalencia
				});
				break;
			}
		}
	}

	return {
		total_entries: entries.length,
		cumpCodes,
		cumpNaoConcluida,
		failedNeverApproved,
		equivMatrPerdido
	};
}

// ─── Main ───────────────────────────────────────────────────────────────────
async function main() {
	console.error(`[audit] Conectando (read-only) em ${new URL(SUPABASE_URL).host} ...`);

	const [dadosUsers, equivalenciasRaw] = await Promise.all([
		fetchAll('dados_users', 'id_dado_user,id_user,semestre_atual,fluxograma_atual', 'id_dado_user'),
		fetchAll(
			'equivalencias',
			'id_equivalencia,id_curso,expressao_original,expressao_logica,materias!equivalencias_id_materia_fkey(codigo_materia)',
			'id_equivalencia'
		)
	]);

	const equivalencias = equivalenciasRaw.map((e) => ({
		id_equivalencia: e.id_equivalencia,
		id_curso: e.id_curso,
		codigo_origem: norm(e.materias?.codigo_materia),
		codigos_equivalentes: [...codesFromEquivalencia(e)]
	}));

	console.error(
		`[audit] ${dadosUsers.length} linhas em dados_users, ${equivalencias.length} equivalências.`
	);

	const results = [];
	let semFluxograma = 0;
	for (const row of dadosUsers) {
		const parsed = parseFluxograma(row.fluxograma_atual);
		if (!parsed || parsed.entries.length === 0) {
			semFluxograma++;
			continue;
		}
		const audit = auditUser(parsed.entries, equivalencias);
		results.push({ id_user: row.id_user, id_dado_user: row.id_dado_user, ...audit });
	}

	// Opcional: mesma auditoria sobre snapshots históricos (jsonb)
	let historicosAfetados = null;
	if (USE_HISTORICOS) {
		const hist = await fetchAll(
			'historicos_usuarios',
			'id_historico,id_user,created_at,fluxograma_atual',
			'id_historico'
		);
		historicosAfetados = [];
		for (const h of hist) {
			const parsed = parseFluxograma(h.fluxograma_atual);
			if (!parsed || parsed.entries.length === 0) continue;
			const a = auditUser(parsed.entries, equivalencias);
			if (a.equivMatrPerdido.length || a.cumpNaoConcluida.length) {
				historicosAfetados.push({
					id_historico: h.id_historico,
					id_user: h.id_user,
					created_at: h.created_at,
					cumpNaoConcluida: a.cumpNaoConcluida,
					equivMatrPerdido: a.equivMatrPerdido
				});
			}
		}
	}

	// ── Agregados ──
	const usersComCump = results.filter((r) => r.cumpCodes.length > 0);
	const usersCumpNaoConcluida = results.filter((r) => r.cumpNaoConcluida.length > 0);
	const usersFailedNeverApproved = results.filter((r) => r.failedNeverApproved.length > 0);
	const usersEquivMatrPerdido = results.filter((r) => r.equivMatrPerdido.length > 0);
	const usersEquivMatrVermelha = results.filter((r) =>
		r.equivMatrPerdido.some((x) => x.renderiza_como.startsWith('REPROVADA'))
	);

	const summary = {
		gerado_em: new Date().toISOString(),
		host: new URL(SUPABASE_URL).host,
		total_dados_users: dadosUsers.length,
		sem_fluxograma_valido: semFluxograma,
		usuarios_auditados: results.length,
		a_aproveitamento: {
			usuarios_com_cump_ou_disp_persistido: usersComCump.length,
			usuarios_cump_persistido_mas_nao_concluida: usersCumpNaoConcluida.length,
			usuarios_proxy_cump_perdido_rep_sem_aprovacao: usersFailedNeverApproved.length,
			nota: 'CUMP descartado pelo parser NÃO é detectável (bruto não persistido); a 3a métrica é proxy superestimado (inclui reprovações reais ainda não refeitas).'
		},
		b_matriculado_em_equivalente: {
			usuarios_com_equivalente_matr_perdido: usersEquivMatrPerdido.length,
			usuarios_renderizando_vermelho_indevido: usersEquivMatrVermelha.length,
			nota: 'Detecção direta: MATR no código equivalente + obrigatória alvo não aprovada/sem MATR direto. "vermelho indevido" = alvo também tem REP anterior (caso FGA0147 do relatório).'
		},
		detalhes: {
			cump_nao_concluida: usersCumpNaoConcluida.map((r) => ({
				id_user: r.id_user,
				codigos: r.cumpNaoConcluida
			})),
			equivalente_matr_perdido: usersEquivMatrPerdido.map((r) => ({
				id_user: r.id_user,
				casos: r.equivMatrPerdido
			})),
			proxy_cump_perdido: usersFailedNeverApproved.map((r) => ({
				id_user: r.id_user,
				codigos: r.failedNeverApproved
			}))
		},
		...(historicosAfetados ? { historicos_afetados: historicosAfetados } : {})
	};

	if (OUT_JSON) {
		console.log(JSON.stringify(summary, null, 2));
		return;
	}

	console.log('==========================================================');
	console.log(' AUDITORIA READ-ONLY — aproveitamento (CUMP) e equivalente MATR');
	console.log('==========================================================');
	console.log(`Banco: ${summary.host}`);
	console.log(`dados_users: ${summary.total_dados_users} linhas | auditados: ${summary.usuarios_auditados} | sem fluxograma válido: ${summary.sem_fluxograma_valido}`);
	console.log('');
	console.log('(a) Aproveitamento (CUMP/DISP):');
	console.log(`    - usuários com CUMP/DISP persistido ............... ${usersComCump.length}`);
	console.log(`    - CUMP persistido mas não contado como concluída .. ${usersCumpNaoConcluida.length}  (esperado 0)`);
	console.log(`    - PROXY CUMP perdido (REP/TRANC sem aprovação) .... ${usersFailedNeverApproved.length}  (superestimado)`);
	console.log('');
	console.log('(b) Matriculado em Equivalente perdido:');
	console.log(`    - usuários afetados ............................... ${usersEquivMatrPerdido.length}`);
	console.log(`    - dos quais renderizam VERMELHO indevido .......... ${usersEquivMatrVermelha.length}`);
	console.log('');
	for (const r of usersEquivMatrPerdido) {
		for (const c of r.equivMatrPerdido) {
			console.log(`    id_user=${r.id_user}: ${c.obrigatoria} <- MATR em ${c.equivalente_matr} (eq #${c.id_equivalencia}) → ${c.renderiza_como}`);
		}
	}
	if (usersCumpNaoConcluida.length) {
		console.log('');
		console.log('CUMP persistido mas não concluída (inconsistência):');
		for (const r of usersCumpNaoConcluida) {
			console.log(`    id_user=${r.id_user}: ${r.cumpNaoConcluida.join(', ')}`);
		}
	}
	console.log('');
	console.log('Use --json para saída completa (inclui proxy por usuário); --historicos para auditar snapshots em historicos_usuarios.');
}

main().catch((err) => {
	console.error('[audit] Falha:', err.message);
	process.exit(1);
});
