<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import PageBackground from '$lib/components/effects/PageBackground.svelte';
	import MontadorGradeView from '$lib/components/planejamento/MontadorGradeView.svelte';
	import AssistenteChatFab from '$lib/components/planejamento/AssistenteChatFab.svelte';
	import { authStore } from '$lib/stores/auth';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { planoFormaturaStore } from '$lib/stores/plano-formatura.store.svelte';
	import { gradeStore, lerPoolSalvo, lerRemovidasSalvo } from '$lib/stores/grade.store.svelte';
	import {
		construirMateriasGrade,
		candidatosDaMatriz,
		escolherAteOLimite,
		motivoParaNaoAdicionar,
		pendenciasPreRequisito,
		invalidarContextoGrade,
		type SemeaduraResultado,
		type PendenciaPreRequisito
	} from '$lib/services/grade-pool.service';
	import PreRequisitoConfirmDialog from '$lib/components/planejamento/PreRequisitoConfirmDialog.svelte';
	import { vagaAssinaturasStore } from '$lib/stores/vaga-assinaturas.store.svelte';
	import { getPeriodoAtivo } from '$lib/services/turmas.service';
	import { preferenciasGradeService } from '$lib/services/preferencias-grade.service';
	import { filtrarNaoCursados } from '$lib/utils/subject-codes';
	import { ROUTES } from '$lib/config/routes';
	import type { SemestrePlano, ItemSemestre, MateriaPlano } from '$lib/types/plano-formatura';
	import { CalendarDays, Loader2 } from 'lucide-svelte';
	import { toast } from 'svelte-sonner';



	let status = $state<'loading' | 'ready' | 'error'>('loading');
	let erro = $state<string | null>(null);
	let periodo = $state<string | null>(null);
	let semestreLabel = $state<string | null>(null);
	let avisoAdd = $state<string | null>(null);

	/**
	 * Prévia pendente de um rearranjo pedido por professor via chat: já aplicada no
	 * `gradeStore` (pra o aluno ver o resultado), mas só persiste no banco e vira
	 * definitiva se ele "Aceitar" — "Manter grade anterior" volta pro snapshot.
	 */
	let confirmacaoProfessor = $state<{
		resumo: string;
		snapshot: Record<string, number>;
		docentes: Record<string, string>;
	} | null>(null);

	function isMateriaPlano(item: ItemSemestre): item is MateriaPlano {
		return 'codigo' in item;
	}

	function extrairRecomendado(): SemestrePlano | null {
		const p = planoFormaturaStore.plano as { plano?: SemestrePlano[] } | null;
		const semestres = p?.plano ?? [];
		return (
			semestres.find((s) => s.tipo === 'recomendado') ??
			semestres.find((s) => s.tipo !== 'em_curso') ??
			semestres[0] ??
			null
		);
	}

	/** Códigos do semestre recomendado pelo plano de formatura. */
	function codigosRecomendados(): string[] {
		const recomendado = extrairRecomendado();
		return recomendado ? recomendado.materias.filter(isMateriaPlano).map((m) => m.codigo) : [];
	}

	/**
	 * Traz para a lista o que "Montar grade" precisa montar.
	 *
	 * Primeiro o semestre recomendado do plano de formatura. Se ele não render nada
	 * montável — semestre só com slots de optativa, plano que falhou ao gerar, ou
	 * tudo já cursado —, cai na matriz e pega o que cabe no limite de créditos, para
	 * o clique nunca terminar sem grade.
	 *
	 * Roda a cada montagem e é idempotente: só entra o que falta na lista, o que o
	 * aluno tirou na lixeira não volta, e matéria já cursada nunca entra.
	 */
	async function semear(): Promise<SemeaduraResultado> {
		if (!periodo) return { doPlano: [], daMatriz: [] };

		const candidatos = filtrarNaoCursados(
			codigosRecomendados().filter(
				(c) => !gradeStore.removidas.has(c) && !gradeStore.hasMateria(c)
			),
			fluxogramaStore.completedCodes,
			fluxogramaStore.currentCodes ?? new Set<string>()
		);
		const doPlano = candidatos.length > 0 ? await construirMateriasGrade(candidatos, periodo) : [];
		for (const m of doPlano) gradeStore.addMateriaAoPool(m);

		// A matriz só entra quando não há NADA montável na lista: quem curou a própria
		// seleção não quer meia matriz despejada em cima dela. Matéria sem turma no
		// período não conta como montável — ela não vira bloco no calendário.
		if (gradeStore.pool.some((m) => m.turmas.length > 0)) {
			return { doPlano: doPlano.map((m) => m.codigo), daMatriz: [] };
		}

		const daMatriz = escolherAteOLimite(
			await candidatosDaMatriz(periodo, [
				...gradeStore.removidas,
				...gradeStore.pool.map((m) => m.codigo)
			]),
			limiteCreditos
		);
		for (const m of daMatriz) gradeStore.addMateriaAoPool(m);

		return { doPlano: doPlano.map((m) => m.codigo), daMatriz: daMatriz.map((m) => m.codigo) };
	}

	async function montar(): Promise<void> {
		status = 'loading';
		erro = null;
		try {
			if (!fluxogramaStore.state.courseData) {
				const matriz = authStore.getUser()?.dadosFluxograma?.matrizCurricular ?? null;
				if (!matriz) {
					goto(ROUTES.UPLOAD_HISTORICO);
					return;
				}
				await fluxogramaStore.loadCourseDataByCurriculoCompleto(matriz);
			}

			await planoFormaturaStore.loadPreferencias();
			if (!planoFormaturaStore.plano) await planoFormaturaStore.gerar();
			// `gerar()` engole a falha: deixa `plano` nulo e devolve normalmente. Sem
			// dizer nada aqui, a lista aparecia vazia sem explicação e a culpa sobrava
			// para o montador.
			if (!planoFormaturaStore.plano) {
				avisoAdd = planoFormaturaStore.error
					? `Não consegui carregar seu plano de formatura (${planoFormaturaStore.error}). "Montar grade" vai puxar da sua matriz.`
					: 'Seu plano de formatura não indicou matérias para o próximo semestre. "Montar grade" vai puxar da sua matriz.';
			}

			semestreLabel = extrairRecomendado()?.semestre ?? null;
			const recomendadoCodigos = codigosRecomendados();

			const idUser = authStore.getUser()?.idUser ?? null;
			periodo = await getPeriodoAtivo();
			const salvos = lerPoolSalvo(idUser, periodo);
			const removidas = new Set(lerRemovidasSalvo(idUser, periodo));
			// Salvos vêm primeiro (não re-adiciona removidas); recomendado só o que não foi removido.
			// O filtro de já-cursadas vale também para os `salvos`: matéria concluída depois de
			// ter entrado no pool some sozinha no próximo carregamento, sem o aluno ter que remover.
			const todos = filtrarNaoCursados(
				[...new Set([...salvos, ...recomendadoCodigos])].filter((c) => !removidas.has(c)),
				fluxogramaStore.completedCodes,
				fluxogramaStore.currentCodes ?? new Set<string>()
			);

			// Matérias que o aluno já está cursando agora entram à parte — o filtro
			// acima existe justamente pra tirar quem já está "em curso", então elas
			// nunca passariam por ele. Aqui só respeita o que ele já tirou na lixeira.
			const cursandoCodigos = [...(fluxogramaStore.currentCodes ?? new Set<string>())].filter(
				(c) => !removidas.has(c)
			);

			const pool = await construirMateriasGrade([...new Set([...todos, ...cursandoCodigos])], periodo);
			gradeStore.init(pool, { idUser, periodo });
			gradeStore.definirCursandoAtual(cursandoCodigos);
			invalidarContextoGrade();
			status = 'ready';
			// Carrega assinaturas de vaga em background (habilita "seguir turma lotada").
			void vagaAssinaturasStore.load();
			// Preferência de professor confirmada numa sessão anterior — carrega em
			// background pra não travar a tela; se falhar, o montador segue sem ela.
			void preferenciasGradeService.listar().then((prefs) => {
				const mapa: Record<string, string> = {};
				for (const p of prefs) if (p.docente) mapa[p.codigo_materia] = p.docente;
				gradeStore.definirDocentesPersistidos(mapa);
			});
		} catch (e) {
			erro = e instanceof Error ? e.message : 'Erro ao montar a grade.';
			status = 'error';
		}
	}

	onMount(() => {
		void montar();
	});

	const limiteCreditos = $derived(planoFormaturaStore.preferencias?.limiteCreditos ?? 24);

	async function adicionarAoPool(codigo: string): Promise<void> {
		avisoAdd = null;
		const c = codigo.trim().toUpperCase();
		if (!periodo) return;
		if (gradeStore.hasMateria(c)) return;
		const impedimento = motivoParaNaoAdicionar(c);
		if (impedimento) {
			avisoAdd = impedimento;
			return;
		}
		try {
			const [m] = await construirMateriasGrade([c], periodo);
			if (m) {
				gradeStore.addMateriaAoPool(m);
			} else {
				avisoAdd = `Não encontrei a matéria ${c}.`;
			}
		} catch {
			avisoAdd = `Erro ao adicionar ${c}.`;
		}
	}

	/**
	 * Pré-requisito pendente vira confirmação explícita antes de entrar no pool.
	 *
	 * A busca (`MateriaSearchAdd`) já faz esse guard sozinha; aqui cobrimos os
	 * caminhos que passam pela rota — a Darcy sugerindo uma matéria e a ação
	 * [MONTAR_GRADE|...], que chega com vários códigos de uma vez. O aviso não
	 * bloqueia: o aluno pode estar cursando o pré-requisito agora (MATR) e ter
	 * motivo legítimo para se inscrever mesmo assim.
	 */
	let pendencias = $state<PendenciaPreRequisito[]>([]);
	/** Códigos represados esperando o "Adicionar mesmo assim". */
	let aguardando = $state<string[]>([]);
	/** O que rodar depois de o lote entrar no pool (montagem do chat). */
	let aposConfirmar = $state<(() => Promise<void>) | null>(null);

	async function adicionarCodigos(codigos: string[]): Promise<void> {
		for (const raw of codigos) {
			const c = raw.trim().toUpperCase();
			if (!c) continue;
			await adicionarAoPool(c);
		}
	}

	async function resolverPendencias(): Promise<void> {
		const codigos = aguardando;
		const depois = aposConfirmar;
		pendencias = [];
		aguardando = [];
		aposConfirmar = null;
		if (codigos.length > 0) await adicionarCodigos(codigos);
		if (depois) await depois();
	}

	function descartarPendencias(): void {
		pendencias = [];
		aguardando = [];
		aposConfirmar = null;
	}

	/** Caminho de uma matéria só — a Darcy sugerindo no chat. */
	async function adicionarComAviso(codigo: string): Promise<void> {
		const p = pendenciasPreRequisito([codigo]);
		if (p.length > 0) {
			pendencias = p;
			aguardando = [codigo];
			aposConfirmar = null;
			return;
		}
		await adicionarAoPool(codigo);
	}

	/**
	 * Ação vinda do chat ([MONTAR_GRADE|...]): garante as matérias no pool, marca-as
	 * como prioritárias e monta — mantendo as demais que couberem sem conflito.
	 *
	 * Quando vem professor (`docentes`), o filtro é rígido e pode rearranjar o resto
	 * da grade pra abrir espaço — por isso vira uma prévia com "Aceitar"/"Manter
	 * grade anterior" em vez de aplicar direto: o aluno confere antes de confirmar.
	 */
	async function montarGradeComPrioridade(
		codigos: string[],
		turnos?: string[],
		docentes?: Record<string, string>
	): Promise<void> {
		if (turnos && turnos.length > 0) gradeStore.setTurnos(turnos);
		const todosCodigos = [...new Set([...codigos, ...Object.keys(docentes ?? {})])];

		// Um diálogo agregado para o lote inteiro — uma fila de pop-ups, um por
		// matéria, seria insuportável quando a Darcy sugere meia grade.
		const p = pendenciasPreRequisito(todosCodigos);
		if (p.length > 0) {
			pendencias = p;
			aguardando = todosCodigos;
			aposConfirmar = () => aplicarMontagemDoChat(todosCodigos, docentes);
			return;
		}

		await adicionarCodigos(todosCodigos);
		await aplicarMontagemDoChat(todosCodigos, docentes);
	}

	/** Prioriza o que o chat pediu e monta — já com o lote garantido no pool. */
	async function aplicarMontagemDoChat(
		todosCodigos: string[],
		docentes?: Record<string, string>
	): Promise<void> {
		for (const raw of todosCodigos) {
			const c = raw.trim().toUpperCase();
			if (!c) continue;
			if (gradeStore.hasMateria(c) && !gradeStore.isPrioritaria(c)) {
				gradeStore.togglePrioridade(c);
			}
		}

		if (docentes && Object.keys(docentes).length > 0) {
			const snapshot = gradeStore.snapshotSelecao();
			gradeStore.montarAutomatico({ docentesObrigatorios: docentes, limiteCreditos });
			const resumo = Object.entries(docentes)
				.map(([c, nome]) => `${c} com ${nome}`)
				.join(', ');
			confirmacaoProfessor = { resumo, snapshot, docentes };
		} else {
			gradeStore.montarAutomatico({ limiteCreditos });
		}
	}

	/** Confirma o rearranjo pedido por professor: persiste no banco pra próxima vez. */
	async function aceitarConfirmacaoProfessor(): Promise<void> {
		if (!confirmacaoProfessor) return;
		const { docentes } = confirmacaoProfessor;
		confirmacaoProfessor = null;
		gradeStore.definirDocentesPersistidos({ ...gradeStore.docentesPersistidos, ...docentes });
		try {
			for (const [codigo, docente] of Object.entries(docentes)) {
				await preferenciasGradeService.salvar(codigo, { docente });
			}
			toast.success('Combinado — vou lembrar dessa preferência da próxima vez.');
		} catch {
			// Best-effort: a preferência já vale nesta sessão mesmo se o banco falhar,
			// só não sobrevive a um reload.
			toast.info('Apliquei na grade, mas não consegui salvar pra lembrar depois.');
		}
	}

	/** Recusa o rearranjo: volta pra grade de antes do pedido de professor. */
	function recusarConfirmacaoProfessor(): void {
		if (!confirmacaoProfessor) return;
		gradeStore.restaurarSelecao(confirmacaoProfessor.snapshot);
		confirmacaoProfessor = null;
	}
</script>

<PageMeta
	title="Montador de Grade | NoFluxo UNB"
	description="Monte e simule sua grade horária do próximo semestre sem conflito de horário."
	noIndex={true}
/>

<PageBackground />

{#if status === 'loading'}
	<div class="relative z-10 flex items-center justify-center gap-2 py-20 text-white/60">
		<Loader2 class="h-5 w-5 animate-spin" /> Carregando matérias e turmas...
	</div>
{:else if status === 'error'}
	<div class="relative z-10 mx-auto w-full max-w-2xl px-4 py-20">
		<div
			class="rounded-2xl border border-red-300/30 bg-red-500/10 px-4 py-6 text-center text-sm text-red-200"
		>
			{erro}
		</div>
	</div>
{:else}
	<MontadorGradeView
		{periodo}
		{semestreLabel}
		{limiteCreditos}
		onAdd={adicionarAoPool}
		onSemear={semear}
		bind:aviso={avisoAdd}
		{confirmacaoProfessor}
		onAceitarConfirmacaoProfessor={aceitarConfirmacaoProfessor}
		onRecusarConfirmacaoProfessor={recusarConfirmacaoProfessor}
	/>

	<!-- Chatbot flutuante (Darcy) — recomenda optativas com turma e insere na grade -->
	<AssistenteChatFab onAddToGrade={adicionarComAviso} onMontarGrade={montarGradeComPrioridade} />

	<PreRequisitoConfirmDialog
		{pendencias}
		onConfirmar={resolverPendencias}
		onCancelar={descartarPendencias}
	/>
{/if}
