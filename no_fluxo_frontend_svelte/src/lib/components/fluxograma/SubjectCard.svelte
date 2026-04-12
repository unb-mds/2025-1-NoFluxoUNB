<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import {
		SubjectStatusEnum,
		canBeTaken,
		hasPrerequisites,
		type SubjectStatusValue
	} from '$lib/types/materia';
	import { satisfazPreRequisitos } from '$lib/types/curso';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { getAncestorAndDescendantCodes } from '$lib/utils/curriculum-graph';

	interface Props {
		materia: MateriaModel;
		/** Optativa colocada manualmente no fluxograma (badge). */
		showOptBadge?: boolean;
		/** Abrir modal de detalhes (nome evita conflito com `onclick` do Svelte no `<button>`) */
		onOpenDetails?: () => void;
		onlongpress?: () => void;
	}

	let { materia, showOptBadge = false, onOpenDetails, onlongpress }: Props = $props();

	const store = fluxogramaStore;
	/** Garante re-render ao mudar histórico / optativas (store em .svelte.ts). */
	let status = $derived.by(() => {
		void store.diagramLayoutRevision;
		void store.userFluxograma;
		return store.getSubjectStatus(materia);
	});
	let userData = $derived.by(() => {
		void store.diagramLayoutRevision;
		void store.userFluxograma;
		return store.getSubjectUserData(materia.codigoMateria);
	});
	let concluidaPorEquivalencia = $derived(
		status === SubjectStatusEnum.COMPLETED && userData?.tipoDado === 'equivalencia'
	);

	let isSelected = $derived(store.state.selectedSubjectCode === materia.codigoMateria);
	let connectionsEnabled = $derived(store.state.connectionMode !== 'off');
	/** No modo "Todas", desktop usa clique para fixar foco (como 1º toque no mobile); hover usa só pré-visualização */
	let isAllConnectionsMode = $derived(store.state.connectionMode === 'all');

	/** Matéria sob a qual calculamos pré-requisitos/dependentes (transitivo no grafo da grade). */
	let focusSubjectCode = $derived.by(() => {
		void store.state.hoverPreviewSubjectCode;
		void store.state.hoveredSubjectCode;
		const p = store.state.hoverPreviewSubjectCode?.trim();
		const h = store.state.hoveredSubjectCode?.trim();
		return p || h || null;
	});

	let focusActive = $derived(focusSubjectCode !== null);

	let highlightRole = $derived.by(() => {
		void store.state.hoverPreviewSubjectCode;
		void store.state.hoveredSubjectCode;
		const curso = store.state.courseData;
		const focus = focusSubjectCode;
		if (!curso || !focus) return null;
		const self = materia.codigoMateria.trim().toUpperCase();
		const f = focus.toUpperCase();
		if (self === f) return 'focus' as const;
		const { ancestors, descendants } = getAncestorAndDescendantCodes(curso, focus);
		if (ancestors.has(self)) return 'ancestor' as const;
		if (descendants.has(self)) return 'descendant' as const;
		return null;
	});

	// Prerequisite indicator: count dependents
	let dependentCount = $derived.by(() => {
		if (!store.state.courseData) return 0;
		return store.state.courseData.materias.filter(
			(m) => m.preRequisitos?.some((p) => p.codigoMateria === materia.codigoMateria)
		).length;
	});

	let hasPrereqs = $derived(hasPrerequisites(materia));
	/** Igual a determineSubjectStatus: prioriza pre_requisitos do curso (incl. requisito fora da grade + equivalência). */
	let prereqsCompleted = $derived.by(() => {
		const curso = store.state.courseData;
		const rows = curso?.preRequisitos?.filter((pr) => pr.idMateria === materia.idMateria) ?? [];
		if (rows.length > 0) {
			return satisfazPreRequisitos(rows, store.completedCodes);
		}
		if (!hasPrerequisites(materia)) return true;
		return canBeTaken(materia, store.completedCodes);
	});

	const gradientMap: Record<SubjectStatusValue, string> = {
		[SubjectStatusEnum.COMPLETED]: 'from-green-500 to-green-700',
		[SubjectStatusEnum.IN_PROGRESS]: 'from-purple-400 to-purple-600',
		[SubjectStatusEnum.AVAILABLE]: 'from-amber-500 to-amber-700',
		[SubjectStatusEnum.FAILED]: 'from-red-500 to-red-700',
		[SubjectStatusEnum.LOCKED]: 'from-white/10 to-white/5',
		[SubjectStatusEnum.NOT_STARTED]: 'from-white/10 to-white/5'
	};

	let cardClasses = $derived.by(() => {
		const gradient = gradientMap[status];
		const base = `subject-card relative flex w-full max-w-[220px] min-w-0 flex-col text-left cursor-pointer rounded-xl border p-3 transition-all duration-200 sm:max-w-[240px]`;
		if (isSelected) {
			return `${base} bg-gradient-to-br ${gradient} border-white/60 ring-2 ring-white/30 opacity-100`;
		}
		let borderExtras = 'border-white/10';
		const role = highlightRole;
		if (role === 'focus') {
			borderExtras = 'border-white/45 ring-2 ring-white/35 shadow-lg';
		} else if (role === 'ancestor') {
			borderExtras = 'border-purple-400/55 ring-2 ring-purple-500/40 shadow-md shadow-purple-900/20';
		} else if (role === 'descendant') {
			borderExtras = 'border-teal-400/55 ring-2 ring-teal-500/40 shadow-md shadow-teal-900/20';
		}
		const dimmed =
			focusActive && role === null ? 'opacity-45' : 'opacity-100';
		return `${base} bg-gradient-to-br ${gradient} ${borderExtras} ${dimmed}`;
	});

	let textColor = $derived(
		status === SubjectStatusEnum.LOCKED || status === SubjectStatusEnum.NOT_STARTED
			? 'text-white/60'
			: 'text-white'
	);

	// Track if this is a touch device interaction
	let isTouchInteraction = $state(false);

	function handleMouseEnter() {
		if (isTouchInteraction) return;
		if (isAllConnectionsMode) {
			store.setHoverPreviewSubject(materia.codigoMateria);
		} else {
			store.setHoveredSubject(materia.codigoMateria);
		}
	}

	function handleMouseLeave() {
		if (isTouchInteraction) return;
		if (isAllConnectionsMode) {
			store.setHoverPreviewSubject(null);
		} else {
			store.setHoveredSubject(null);
		}
	}

	// Long-press and drag detection for mobile
	let longPressTimer: ReturnType<typeof setTimeout> | null = null;
	let didLongPress = false;
	let startX = 0;
	let startY = 0;
	let didDrag = false;
	const DRAG_THRESHOLD = 10; // pixels
	const LONG_PRESS_MS = 400; // reduzido para mobile

	function handleTouchStart(e: TouchEvent) {
		isTouchInteraction = true;
		didLongPress = false;
		didDrag = false;

		const touch = e.touches[0];
		startX = touch.clientX;
		startY = touch.clientY;

		longPressTimer = setTimeout(() => {
			didLongPress = true;
			store.setHoveredSubject(materia.codigoMateria);
			if (!store.state.isAnonymous) {
				onlongpress?.();
			}
		}, LONG_PRESS_MS);
	}

	function handleTouchMove(e: TouchEvent) {
		if (longPressTimer) {
			const touch = e.touches[0];
			const deltaX = Math.abs(touch.clientX - startX);
			const deltaY = Math.abs(touch.clientY - startY);

			if (deltaX > DRAG_THRESHOLD || deltaY > DRAG_THRESHOLD) {
				clearTimeout(longPressTimer);
				longPressTimer = null;
				didDrag = true;
			}
		}
	}

	function handleTouchEnd() {
		if (longPressTimer) {
			clearTimeout(longPressTimer);
			longPressTimer = null;
		}

		if (!didDrag && !didLongPress) {
			// Tap rápido: modo mobile para conexões
			const c = materia.codigoMateria?.trim();
			const h = store.state.hoveredSubjectCode?.trim();
			const alreadyHovered = !!c && h?.toUpperCase() === c.toUpperCase();
			if (connectionsEnabled) {
				// Primeiro toque: mostra conexões. Segundo toque no mesmo card: abre modal
				if (alreadyHovered) {
					onOpenDetails?.();
				} else {
					store.setHoveredSubject(materia.codigoMateria);
				}
			} else {
				store.setHoveredSubject(null);
				onOpenDetails?.();
			}
		}

		didLongPress = false;
		didDrag = false;

		setTimeout(() => {
			isTouchInteraction = false;
		}, 300);
	}

	function handleTouchCancel() {
		if (longPressTimer) {
			clearTimeout(longPressTimer);
			longPressTimer = null;
		}
		didLongPress = false;
		didDrag = false;
		setTimeout(() => {
			isTouchInteraction = false;
		}, 300);
	}

	// Desktop pointer events (for right-click context menu and normal click)
	function handleClick() {
		if (isTouchInteraction) return;
		// Modo "Todas": igual ao mobile — 1º clique foca pré-reqs/dependentes; 2º no mesmo card abre detalhes
		if (isAllConnectionsMode && connectionsEnabled) {
			const code = materia.codigoMateria?.trim();
			const hovered = store.state.hoveredSubjectCode?.trim();
			const alreadyHovered = !!code && hovered?.toUpperCase() === code.toUpperCase();
			if (alreadyHovered) {
				onOpenDetails?.();
			} else {
				store.setHoveredSubject(materia.codigoMateria);
			}
			return;
		}
		onOpenDetails?.();
	}

	function handleContextMenu(e: MouseEvent) {
		if (!store.state.isAnonymous && onlongpress) {
			e.preventDefault();
			onlongpress();
		}
	}
</script>

<button
	class={cardClasses}
	data-subject-code={materia.codigoMateria}
	style="touch-action: none;"
	onclick={handleClick}
	oncontextmenu={handleContextMenu}
	onmouseenter={handleMouseEnter}
	onmouseleave={handleMouseLeave}
	ontouchstart={handleTouchStart}
	ontouchmove={handleTouchMove}
	ontouchend={handleTouchEnd}
	ontouchcancel={handleTouchCancel}
	role="button"
	tabindex="0"
>
	<div class="mb-1 flex shrink-0 items-center justify-between gap-1">
		<span class="text-[10px] font-semibold uppercase tracking-wider {textColor} opacity-80">
			{materia.codigoMateria}
			{#if showOptBadge}
				<span
					class="ml-1 rounded bg-purple-500/85 px-1 py-px text-[8px] font-bold normal-case text-white"
					title="Optativa planejada no fluxograma"
				>(opt)</span>
			{/if}
		</span>
		<div class="flex items-center gap-1">
			<span class="text-[10px] {textColor} opacity-60">
				{materia.creditos}cr
			</span>
		</div>
	</div>
	<!-- Bloco do nome com altura fixa: não estica o card; nome completo no tooltip -->
	<div class="h-[2.25rem] shrink-0 overflow-hidden">
		<p
			class="line-clamp-2 break-words text-xs font-medium leading-[1.125rem] {textColor}"
			title={materia.nomeMateria}
		>
			{materia.nomeMateria}
		</p>
	</div>

	{#if concluidaPorEquivalencia}
		<span
			class="absolute -right-1 -bottom-1 rounded bg-purple-500/90 px-1.5 py-0.5 text-[9px] font-medium text-white"
			title="Concluída por equivalência"
		>equiv.</span>
	{/if}

	<!-- Prerequisite indicator badge -->
	{#if !store.state.isAnonymous && (hasPrereqs || dependentCount > 0)}
		<div class="absolute -left-1 -bottom-1 flex items-center gap-0.5 rounded-full px-1.5 py-0.5 text-[9px] font-bold {prereqsCompleted ? 'bg-green-500/80 text-white' : 'bg-amber-500/80 text-white'}">
			{#if hasPrereqs}
				<span>{prereqsCompleted ? '✓' : '!'}</span>
			{/if}
			{#if dependentCount > 0}
				<span class="border-l border-white/30 pl-0.5">{dependentCount}</span>
			{/if}
		</div>
	{/if}

</button>
