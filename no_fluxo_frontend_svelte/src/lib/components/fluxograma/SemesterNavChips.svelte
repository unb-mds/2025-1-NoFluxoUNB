<script lang="ts">
	import { browser } from '$app/environment';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import {
		matchesFluxogramCompactTouchMode,
		FLUXOGRAM_NARROW_QUERY,
		FLUXOGRAM_COMPACT_LANDSCAPE_QUERY
	} from '$lib/utils/fluxogram-viewport';

	/**
	 * Navegação rápida por semestre no mobile — faixa no fluxo da página
	 * (entre o fluxograma e a integralização), fora do overlay para não
	 * cobrir os cards. No modo foco os chips continuam no overlay
	 * (FluxogramViewportChrome).
	 */

	const store = fluxogramaStore;

	/** Mesma condição do chrome compacto (mobile + landscape estreito). */
	let compactTouch = $state(false);

	$effect(() => {
		if (!browser) return;
		const apply = () => {
			compactTouch = matchesFluxogramCompactTouchMode();
		};
		apply();
		const mqNarrow = window.matchMedia(FLUXOGRAM_NARROW_QUERY);
		const mqLand = window.matchMedia(FLUXOGRAM_COMPACT_LANDSCAPE_QUERY);
		mqNarrow.addEventListener('change', apply);
		mqLand.addEventListener('change', apply);
		window.addEventListener('resize', apply);
		return () => {
			mqNarrow.removeEventListener('change', apply);
			mqLand.removeEventListener('change', apply);
			window.removeEventListener('resize', apply);
		};
	});

	let semesterList = $derived.by(() => {
		const keys = new Set<number>();
		for (const k of store.subjectsBySemester.keys()) if (k > 0) keys.add(k);
		for (const k of store.optativasBySemester.keys()) if (k > 0) keys.add(k);
		for (const k of store.extrasCursadasBySemester.keys()) if (k > 0) keys.add(k);
		return Array.from(keys).sort((a, b) => a - b);
	});

	let semestreAtualAluno = $derived(store.userFluxograma?.semestreAtual ?? null);

	function scrollToSemester(n: number) {
		const root = document.querySelector<HTMLElement>('[data-fluxogram-scroll-root]');
		const col = root?.querySelector<HTMLElement>(`[data-semester="${n}"]`);
		if (!root || !col) return;
		const rootRect = root.getBoundingClientRect();
		const colRect = col.getBoundingClientRect();
		root.scrollTo({
			left: Math.max(0, root.scrollLeft + (colRect.left - rootRect.left) - 16),
			behavior: 'smooth'
		});
	}
</script>

{#if compactTouch && semesterList.length > 1}
	<nav
		class="semester-chips -mx-1 flex gap-1.5 overflow-x-auto px-1 py-2"
		aria-label="Ir para um semestre do fluxograma"
	>
		{#each semesterList as sem (sem)}
			<button
				type="button"
				onclick={() => scrollToSemester(sem)}
				class="h-9 min-w-[2.5rem] shrink-0 rounded-full border px-2.5 text-xs font-semibold transition-colors active:scale-95 {sem === semestreAtualAluno
					? 'border-primary/70 bg-primary/85 text-primary-foreground shadow-lg shadow-primary/25'
					: 'border-white/15 bg-white/[0.06] text-white/80'}"
				aria-label="Ir para o semestre {sem}"
			>
				{sem}º
			</button>
		{/each}
	</nav>
{/if}

<style>
	.semester-chips {
		scrollbar-width: none;
	}

	.semester-chips::-webkit-scrollbar {
		display: none;
	}
</style>
