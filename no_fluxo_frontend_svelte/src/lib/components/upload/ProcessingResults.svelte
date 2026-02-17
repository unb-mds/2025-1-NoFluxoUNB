<script lang="ts">
	import { BookOpen, CheckCircle, AlertTriangle, Star } from 'lucide-svelte';
	import DisciplinaList from './DisciplinaList.svelte';
	import type { CasarDisciplinasResponse, UploadPdfResponse } from '$lib/services/upload.service';

	interface Props {
		data: CasarDisciplinasResponse;
		extractedData?: UploadPdfResponse | null;
	}

	let { data, extractedData = null }: Props = $props();

	let stats = $derived([
		{
			label: 'Total de Disciplinas',
			value: data.resumo.total_disciplinas,
			icon: BookOpen,
			color: 'text-purple-400',
			bg: 'bg-purple-500/10'
		},
		{
			label: 'Concluídas',
			value: data.resumo.total_obrigatorias_concluidas,
			icon: CheckCircle,
			color: 'text-emerald-400',
			bg: 'bg-emerald-500/10'
		},
		{
			label: 'Pendentes',
			value: data.resumo.total_obrigatorias_pendentes,
			icon: AlertTriangle,
			color: 'text-orange-400',
			bg: 'bg-orange-500/10'
		},
		{
			label: 'Optativas',
			value: data.resumo.total_optativas,
			icon: Star,
			color: 'text-blue-400',
			bg: 'bg-blue-500/10'
		}
	]);

	let completionPercent = $derived(
		Math.round(data.resumo.percentual_conclusao_obrigatorias * 100) / 100
	);
</script>

<div class="space-y-6">
	<!-- Stats Grid -->
	<div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
		{#each stats as stat}
			<div class="rounded-xl border border-white/5 p-3 text-center {stat.bg}">
				<div class="mx-auto mb-1.5 flex h-8 w-8 items-center justify-center rounded-full {stat.bg}">
					<stat.icon class="h-4 w-4 {stat.color}" />
				</div>
				<p class="text-2xl font-bold text-white">{stat.value}</p>
				<p class="text-xs text-gray-400">{stat.label}</p>
			</div>
		{/each}
	</div>

	<!-- Completion Bar -->
	<div class="rounded-xl border border-white/5 p-4" style="background: rgba(255,255,255,0.03);">
		<div class="mb-2 flex items-center justify-between">
			<span class="text-sm text-gray-400">Progresso do curso</span>
			<span class="text-sm font-semibold text-purple-400">{completionPercent}%</span>
		</div>
		<div class="h-2 overflow-hidden rounded-full bg-white/10">
			<div
				class="h-full rounded-full bg-gradient-to-r from-purple-500 to-pink-500 transition-all duration-500"
				style="width: {Math.min(completionPercent, 100)}%"
			></div>
		</div>
	</div>

	<!-- Validation Data -->
	{#if data.dados_validacao || extractedData}
		<div class="rounded-xl border border-white/5 p-4" style="background: rgba(255,255,255,0.03);">
			<h4 class="mb-3 text-sm font-semibold text-gray-300">Dados de Validação</h4>
			<div class="grid grid-cols-2 gap-3 text-sm">
				{#if data.dados_validacao?.ira != null}
					<div>
						<span class="text-gray-500">IRA</span>
						<p class="font-medium text-white">{data.dados_validacao.ira.toFixed(2)}</p>
					</div>
				{/if}
				{#if data.dados_validacao?.media_ponderada != null}
					<div>
						<span class="text-gray-500">Média Ponderada</span>
						<p class="font-medium text-white">{data.dados_validacao.media_ponderada.toFixed(2)}</p>
					</div>
				{/if}
				{#if data.dados_validacao?.horas_integralizadas != null}
					<div>
						<span class="text-gray-500">Horas Integralizadas</span>
						<p class="font-medium text-white">{data.dados_validacao.horas_integralizadas}h</p>
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
