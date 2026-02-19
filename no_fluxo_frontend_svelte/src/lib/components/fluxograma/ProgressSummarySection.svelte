<script lang="ts">
	import type { CursoModel } from '$lib/types/curso';
	import type { DadosFluxogramaUser } from '$lib/types/user';
	import { getCompletedSubjectCodes, getTotalCreditsCompleted } from '$lib/types/user';
	import { GraduationCap, TrendingUp, Calendar, MessageSquare } from 'lucide-svelte';
	import { goto } from '$app/navigation';
	import { ROUTES } from '$lib/config/routes';

	interface Props {
		courseData: CursoModel;
		userFluxograma: DadosFluxogramaUser | null;
		/** Se informado, usa este total (ex.: inclui concluídas por equivalência); senão usa só histórico */
		effectiveCompletedCount?: number;
	}

	let { courseData, userFluxograma, effectiveCompletedCount }: Props = $props();

	let totalCredits = $derived(courseData.totalCreditos ?? 0);

	let completedCredits = $derived.by(() => {
		if (!userFluxograma) return 0;
		const creditsMap = new Map(
			courseData.materias.map((m) => [m.codigoMateria, m.creditos])
		);
		return getTotalCreditsCompleted(userFluxograma, creditsMap);
	});

	let completedCount = $derived.by(() => {
		if (effectiveCompletedCount !== undefined && effectiveCompletedCount !== null) {
			return effectiveCompletedCount;
		}
		if (!userFluxograma) return 0;
		return getCompletedSubjectCodes(userFluxograma).size;
	});

	let totalSubjects = $derived(courseData.materias.filter((m) => m.nivel > 0).length);

	let completionPercent = $derived(
		totalSubjects > 0 ? Math.round((completedCount / totalSubjects) * 100) : 0
	);

	let creditPercent = $derived(
		totalCredits > 0 ? Math.min(100, Math.round((completedCredits / totalCredits) * 100)) : 0
	);

	let currentSemester = $derived(userFluxograma?.semestreAtual ?? 1);

	// SVG circular progress helper
	function circleProgress(percent: number, radius = 38) {
		const circumference = 2 * Math.PI * radius;
		const offset = circumference - (percent / 100) * circumference;
		return { circumference, offset };
	}

	let creditCircle = $derived(circleProgress(creditPercent));
</script>

{#if userFluxograma}
	<div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
		<!-- Credits progress -->
		<div class="rounded-xl border border-white/10 bg-black/40 p-4 backdrop-blur-md">
			<div class="flex items-center gap-4">
				<div class="relative h-20 w-20 shrink-0">
					<svg class="h-20 w-20 -rotate-90" viewBox="0 0 88 88">
						<circle
							cx="44"
							cy="44"
							r="38"
							stroke="rgba(255,255,255,0.1)"
							stroke-width="6"
							fill="none"
						/>
						<circle
							cx="44"
							cy="44"
							r="38"
							stroke="#22c55e"
							stroke-width="6"
							fill="none"
							stroke-linecap="round"
							stroke-dasharray={creditCircle.circumference}
							stroke-dashoffset={creditCircle.offset}
							class="transition-all duration-700"
						/>
					</svg>
					<div class="absolute inset-0 flex items-center justify-center">
						<span class="text-sm font-bold text-white">{creditPercent}%</span>
					</div>
				</div>
				<div>
					<div class="flex items-center gap-1.5 text-green-400">
						<GraduationCap class="h-4 w-4" />
						<span class="text-xs font-semibold uppercase tracking-wider">Créditos</span>
					</div>
					<p class="mt-1 text-lg font-bold text-white">
						{completedCredits}<span class="text-sm font-normal text-white/50">/{totalCredits}</span>
					</p>
					<p class="text-xs text-white/50">créditos integralizados</p>
				</div>
			</div>
		</div>

		<!-- Completion percentage -->
		<div class="rounded-xl border border-white/10 bg-black/40 p-4 backdrop-blur-md">
			<div class="flex items-center gap-1.5 text-purple-400">
				<TrendingUp class="h-4 w-4" />
				<span class="text-xs font-semibold uppercase tracking-wider">Progresso</span>
			</div>
			<p class="mt-2 text-2xl font-bold text-white">
				{completionPercent}%
			</p>
			<p class="mb-2 text-xs text-white/50">
				{completedCount} de {totalSubjects} matérias concluídas
			</p>
			<div class="h-2 overflow-hidden rounded-full bg-white/10">
				<div
					class="h-full rounded-full bg-gradient-to-r from-purple-500 to-pink-500 transition-all duration-700"
					style="width: {completionPercent}%"
				></div>
			</div>
		</div>

		<!-- Current semester -->
		<div class="rounded-xl border border-white/10 bg-black/40 p-4 backdrop-blur-md">
			<div class="flex items-center gap-1.5 text-amber-400">
				<Calendar class="h-4 w-4" />
				<span class="text-xs font-semibold uppercase tracking-wider">Semestre Atual</span>
			</div>
			<p class="mt-2 text-2xl font-bold text-white">
				{currentSemester}º
			</p>
			<p class="text-xs text-white/50">semestre</p>
			{#if userFluxograma.ira}
				<div class="mt-2 rounded-lg bg-white/5 px-2.5 py-1">
					<span class="text-xs text-white/50">IRA: </span>
					<span class="text-sm font-semibold text-white">{userFluxograma.ira.toFixed(1)}</span>
				</div>
			{/if}
		</div>

		<!-- Assistente CTA -->
		<div class="col-span-full">
			<button
				onclick={() => goto(ROUTES.ASSISTENTE)}
				class="group flex w-full items-center justify-between rounded-xl border border-purple-500/20 bg-gradient-to-r from-purple-500/10 to-pink-500/10 px-5 py-3 transition-all hover:border-purple-500/30 hover:shadow-lg"
			>
				<div class="flex items-center gap-3">
					<MessageSquare class="h-5 w-5 text-purple-400" />
					<div class="text-left">
						<p class="text-sm font-semibold text-white">Precisa de ajuda?</p>
						<p class="text-xs text-white/50">Converse com o assistente sobre seu fluxograma</p>
					</div>
				</div>
				<span class="rounded-full bg-purple-600 px-4 py-1.5 text-xs font-medium text-white transition-colors group-hover:bg-purple-500">
					Falar com Assistente
				</span>
			</button>
		</div>
	</div>
{/if}
