<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import { prerequisitosAprovadosParaRegistrarConcluida } from '$lib/types/materia';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { X, CalendarClock, GraduationCap } from 'lucide-svelte';

	interface Props {
		materia: MateriaModel;
		defaultSemestre?: number;
		ondecidir: (tipo: 'futura' | 'concluida', semestreFuturo?: number) => void;
		onpular?: () => void;
	}

	let { materia, defaultSemestre = 1, ondecidir, onpular }: Props = $props();

	const store = fluxogramaStore;
	let podeMarcarConcluida = $derived(
		prerequisitosAprovadosParaRegistrarConcluida(
			materia,
			store.completedCodes,
			store.completedCodesHistorico,
			store.state.courseData ?? undefined
		)
	);

	let modo = $state<'escolha' | 'futura'>('escolha');
	let semestre = $state(1);

	$effect(() => {
		materia.codigoMateria;
		defaultSemestre;
		modo = 'escolha';
		semestre = Math.max(1, Math.min(20, defaultSemestre));
	});

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onpular?.();
	}
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="fixed inset-0 z-[560] flex items-center justify-center bg-black/70 p-3 backdrop-blur-sm sm:p-4"
	role="presentation"
	onclick={(e) => e.target === e.currentTarget && onpular?.()}
>
	<div
		class="w-full max-w-md overflow-hidden rounded-2xl border border-white/15 bg-gray-950/98 shadow-2xl backdrop-blur-xl"
		role="dialog"
		aria-modal="true"
		tabindex="-1"
		aria-labelledby="opt-tipo-titulo"
		onclick={(e) => e.stopPropagation()}
	>
		<div class="flex items-start justify-between gap-2 border-b border-white/10 px-4 py-3 sm:px-5">
			<div class="min-w-0">
				<h2 id="opt-tipo-titulo" class="text-sm font-bold text-white sm:text-base">Como adicionar esta optativa?</h2>
				<p class="mt-1 line-clamp-2 text-xs text-white/55">{materia.nomeMateria}</p>
				<p class="text-[11px] text-white/40">{materia.codigoMateria} · {materia.creditos} cr</p>
			</div>
			<button
				type="button"
				onclick={() => onpular?.()}
				class="shrink-0 rounded-full p-2 text-white/50 hover:bg-white/10 hover:text-white"
				aria-label="Pular"
			>
				<X class="h-5 w-5" />
			</button>
		</div>

		<div class="space-y-3 px-4 py-4 sm:px-5">
			{#if modo === 'escolha'}
				<p class="text-xs text-white/60">
					<strong class="text-white/85">Futura</strong>: aparece no fluxograma com (opt) e entra no planejamento de carga horária.
					<strong class="text-white/85">Concluída</strong>: entra no seu histórico como aprovada — só é permitido se os pré-requisitos já constarem como aprovados no histórico.
				</p>
				{#if !podeMarcarConcluida}
					<p class="rounded-lg border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-[11px] text-amber-200/90">
						<strong class="text-amber-100">Atenção:</strong> falta base no histórico (obrigatórias podem contar com equivalência da matriz; <strong class="text-amber-50">optativas que são pré-requisito</strong> precisam estar aprovadas no histórico). Use
						<strong class="text-white/90">Matéria futura</strong> ou envie o histórico atualizado.
					</p>
				{/if}
				<button
					type="button"
					onclick={() => (modo = 'futura')}
					class="flex w-full items-center gap-3 rounded-xl border border-purple-500/40 bg-purple-500/15 px-4 py-3 text-left transition-colors hover:bg-purple-500/25"
				>
					<CalendarClock class="h-8 w-8 shrink-0 text-purple-300" />
					<div>
						<p class="text-sm font-semibold text-white">Matéria futura / planejada</p>
						<p class="text-xs text-white/55">Colocar em um semestre do fluxograma</p>
					</div>
				</button>
				<button
					type="button"
					disabled={!podeMarcarConcluida}
					onclick={() => podeMarcarConcluida && ondecidir('concluida')}
					title={!podeMarcarConcluida
						? 'Pré-requisitos no histórico: optativas exigem aprovação registrada (não só equivalência na matriz).'
						: undefined}
					class="flex w-full items-center gap-3 rounded-xl border border-emerald-500/40 bg-emerald-500/10 px-4 py-3 text-left transition-colors hover:bg-emerald-500/20 disabled:cursor-not-allowed disabled:opacity-45 disabled:hover:bg-emerald-500/10"
				>
					<GraduationCap class="h-8 w-8 shrink-0 text-emerald-300" />
					<div>
						<p class="text-sm font-semibold text-white">Já concluí na graduação</p>
						<p class="text-xs text-white/55">Registrar como aprovada no histórico local</p>
					</div>
				</button>
			{:else}
				<button
					type="button"
					onclick={() => (modo = 'escolha')}
					class="text-xs font-medium text-purple-300 hover:text-purple-200"
				>
					← Voltar
				</button>
				<label for="sem-opt-tipo" class="block text-xs font-medium text-white/60">Semestre no fluxograma</label>
				<select
					id="sem-opt-tipo"
					bind:value={semestre}
					class="w-full rounded-lg border border-white/15 bg-white/5 px-3 py-2 text-sm text-white outline-none focus:border-purple-500/50"
				>
					{#each Array.from({ length: 16 }, (_, i) => i + 1) as sem}
						<option value={sem} class="bg-gray-900">{sem}º semestre</option>
					{/each}
				</select>
				<button
					type="button"
					onclick={() => ondecidir('futura', semestre)}
					class="w-full rounded-xl bg-purple-600 py-3 text-sm font-semibold text-white hover:bg-purple-500"
				>
					Confirmar no {semestre}º semestre
				</button>
			{/if}
		</div>
	</div>
</div>
