<script lang="ts">
	import { BookOpen, CheckCircle, AlertTriangle, Star } from 'lucide-svelte';
	import DisciplinaList from './DisciplinaList.svelte';
	import IntegralizacaoSection from '$lib/components/fluxograma/IntegralizacaoSection.svelte';
	import { getIntegralizacao } from '$lib/services/integralizacao.service';
	import { formatarIraParaExibicao } from '$lib/utils/ira';
	import type { CasarDisciplinasResponse, UploadPdfResponse } from '$lib/services/upload.service';
	import type { IntegralizacaoResult } from '$lib/types/matriz';

	interface Props {
		data: CasarDisciplinasResponse;
		extractedData?: UploadPdfResponse | null;
	}

	let { data, extractedData = null }: Props = $props();

	let integralizacao = $state<IntegralizacaoResult | null>(null);

	// Fonte única: carga_horaria_integralizada do PDF. Calcula integralização (exigido da matriz + realizado do PDF).
	$effect(() => {
		const cc = data.matriz_curricular ?? extractedData?.matriz_curricular ?? '';
		const ch = extractedData?.carga_horaria_integralizada;
		if (!cc || !ch) return;
		getIntegralizacao({
			curriculoCompleto: cc,
			dadosFluxograma: null,
			cargaHorariaIntegralizada: ch
		}).then((r) => {
			integralizacao = r;
		});
	});

	// Total só de obrigatórias (nivel > 0), sem optativas; vem do backend ou soma concluídas + pendentes
	let totalObrigatorias = $derived(
		data.resumo.total_obrigatorias ??
			(data.resumo.total_obrigatorias_concluidas ?? 0) + (data.resumo.total_obrigatorias_pendentes ?? 0)
	);

	/** Texto do IRA como no PDF (valor_texto), para não arredondar na tela de validação. */
	let iraTextoHistorico = $derived.by(() => {
		const row = extractedData?.extracted_data?.find(
			(d) => (d as { tipo_dado?: string }).tipo_dado === 'IRA'
		) as { valor_texto?: string } | undefined;
		return row?.valor_texto ?? data.dados_validacao?.ira_texto ?? null;
	});

	let stats = $derived([
		{
			label: 'Total de Obrigatórias',
			value: totalObrigatorias,
			icon: BookOpen,
			color: 'text-purple-400',
			bg: 'bg-purple-500/10',
			title: 'Matérias obrigatórias (nivel > 0): concluídas + pendentes'
		},
		{
			label: 'Concluídas (obrig.)',
			value: data.resumo.total_obrigatorias_concluidas,
			icon: CheckCircle,
			color: 'text-emerald-400',
			bg: 'bg-emerald-500/10',
			title: 'Obrigatórias concluídas (APR/CUMP/DISP ou por equivalência)'
		},
		{
			label: 'Pendentes (obrig.)',
			value: data.resumo.total_obrigatorias_pendentes,
			icon: AlertTriangle,
			color: 'text-orange-400',
			bg: 'bg-orange-500/10',
			title: 'Obrigatórias ainda não concluídas'
		},
		{
			label: 'Optativas',
			value: data.resumo.total_optativas,
			icon: Star,
			color: 'text-blue-400',
			bg: 'bg-blue-500/10',
			title: 'Matérias optativas (nivel = 0)'
		}
	]);

</script>

<div class="min-w-0 space-y-4 sm:space-y-6">
	<!-- Stats Grid -->
	<div class="grid grid-cols-2 gap-2 sm:gap-3 sm:grid-cols-4">
		{#each stats as stat}
			<div class="rounded-xl border border-white/5 p-2.5 text-center sm:p-3 {stat.bg}" title={stat.title}>
				<div class="mx-auto mb-1 flex h-7 w-7 items-center justify-center rounded-full sm:mb-1.5 sm:h-8 sm:w-8 {stat.bg}">
					<stat.icon class="h-3.5 w-3.5 sm:h-4 sm:w-4 {stat.color}" />
				</div>
				<p class="text-xl font-bold text-white sm:text-2xl">{stat.value}</p>
				<p class="text-[10px] text-gray-400 sm:text-xs">{stat.label}</p>
			</div>
		{/each}
	</div>

	<!-- Integralização: círculo clicável (CH do PDF vs matriz) -->
	{#if integralizacao}
		<IntegralizacaoSection integralizacao={integralizacao} />
	{/if}

	<!-- Validation Data (IRA, MP, curso, matriz, semestre — horas vêm da integralização acima) -->
	{#if data.dados_validacao || extractedData}
		<div class="rounded-xl border border-white/5 p-3 sm:p-4" style="background: rgba(255,255,255,0.03);">
			<h4 class="mb-2 text-xs font-semibold text-gray-300 sm:mb-3 sm:text-sm">Dados de Validação</h4>
			<div class="grid grid-cols-2 gap-2 text-xs sm:gap-3 sm:text-sm">
				{#if data.dados_validacao?.ira != null}
					<div>
						<span class="text-gray-500">IRA</span>
						<p class="font-medium text-white">
							{formatarIraParaExibicao(data.dados_validacao.ira, iraTextoHistorico)}
						</p>
					</div>
				{/if}
				{#if data.dados_validacao?.media_ponderada != null}
					<div>
						<span class="text-gray-500">Média Ponderada</span>
						<p class="font-medium text-white">{data.dados_validacao.media_ponderada.toFixed(2)}</p>
					</div>
				{/if}
				{#if extractedData?.curso_extraido}
					<div>
						<span class="text-gray-500">Curso</span>
						<p class="font-medium text-white">{extractedData.curso_extraido}</p>
					</div>
				{/if}
				{#if extractedData?.matriz_curricular}
					<div>
						<span class="text-gray-500">Matriz Curricular</span>
						<p class="font-medium text-white">{extractedData.matriz_curricular}</p>
					</div>
				{/if}
				{#if extractedData?.semestre_atual}
					<div>
						<span class="text-gray-500">Semestre Atual</span>
						<p class="font-medium text-white">{extractedData.semestre_atual}</p>
					</div>
				{/if}
			</div>
		</div>
	{/if}

	<!-- Discipline Lists -->
	<div class="space-y-3">
		{#if data.materias_concluidas?.length}
			<DisciplinaList
				title="Disciplinas Concluídas"
				items={data.materias_concluidas as any[]}
				variant="found"
			/>
		{/if}

		{#if data.materias_pendentes?.length}
			<DisciplinaList
				title="Disciplinas Pendentes"
				items={data.materias_pendentes as any[]}
				variant="missing"
			/>
		{/if}

		{#if data.materias_optativas?.length}
			<DisciplinaList
				title="Disciplinas Optativas"
				items={data.materias_optativas as any[]}
				variant="elective"
			/>
		{/if}
	</div>
</div>
