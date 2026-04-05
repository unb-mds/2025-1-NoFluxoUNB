<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import { SubjectStatusEnum, hasPrerequisites, type SubjectStatusValue } from '$lib/types/materia';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';

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

	let isHovered = $derived(store.state.hoveredSubjectCode === materia.codigoMateria);
	let isSelected = $derived(store.state.selectedSubjectCode === materia.codigoMateria);
	let connectionsEnabled = $derived(store.state.connectionMode !== 'off');
	/** No modo "Todas", desktop usa clique para fixar foco (como 1º toque no mobile); hover não altera o foco */
	let isAllConnectionsMode = $derived(store.state.connectionMode === 'all');

	// Check if this subject is a prerequisite of the hovered subject
	let isPrereqOfHovered = $derived.by(() => {
		if (!connectionsEnabled) return false;
		const hoveredCode = store.state.hoveredSubjectCode;
		if (!hoveredCode || !store.state.courseData) return false;
		const hoveredMateria = store.state.courseData.materias.find(
			(m) => m.codigoMateria === hoveredCode
		);
		if (!hoveredMateria?.preRequisitos) return false;
		return hoveredMateria.preRequisitos.some((p) => p.codigoMateria === materia.codigoMateria);
	});

	// Check if hovered subject is a prerequisite of this subject
	let isDependentOfHovered = $derived.by(() => {
		if (!connectionsEnabled) return false;
		const hoveredCode = store.state.hoveredSubjectCode;
		if (!hoveredCode || !materia.preRequisitos) return false;
		return materia.preRequisitos.some((p) => p.codigoMateria === hoveredCode);
	});

	let isHighlighted = $derived(isHovered || isPrereqOfHovered || isDependentOfHovered);

	// Prerequisite indicator: count dependents
	let dependentCount = $derived.by(() => {
		if (!store.state.courseData) return 0;
		return store.state.courseData.materias.filter(
			(m) => m.preRequisitos?.some((p) => p.codigoMateria === materia.codigoMateria)
		).length;
	});

	let hasPrereqs = $derived(hasPrerequisites(materia));
	let prereqsCompleted = $derived.by(() => {
		if (!hasPrereqs) return true;
		return materia.preRequisitos!.every(
			(p) => store.completedCodes.has(p.codigoMateria)
		);
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
		const borderColor =
			isSelected
				? 'border-white/60 ring-2 ring-white/30'
				: isHighlighted
					? 'border-white/40 shadow-lg'
					: !connectionsEnabled && isHovered
						? 'border-white/30 shadow-md'
						: 'border-white/10';
		const dimmed =
			connectionsEnabled && store.state.hoveredSubjectCode && !isHighlighted ? 'opacity-40' : 'opacity-100';
		return `${base} bg-gradient-to-br ${gradient} ${borderColor} ${dimmed}`;
	});

	let textColor = $derived(
		status === SubjectStatusEnum.LOCKED || status === SubjectStatusEnum.NOT_STARTED
			? 'text-white/60'
			: 'text-white'
	);

	// Track if this is a touch device interaction
	let isTouchInteraction = $state(false);

	function handleMouseEnter() {
		// Don't trigger hover on touch devices (touch followed by mouse events)
		if (!isTouchInteraction && !isAllConnectionsMode) {
			store.setHoveredSubject(materia.codigoMateria);
		}
	}

	function handleMouseLeave() {
		// Don't clear hover on touch devices - it's managed by long-press
		// Modo "Todas": foco só por clique — não limpar ao mover o rato
		if (!isTouchInteraction && !isAllConnectionsMode) {
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

	{#if isPrereqOfHovered && connectionsEnabled}
		<div class="absolute -right-1 -top-1 h-3 w-3 rounded-full bg-purple-400 ring-2 ring-black"></div>
	{/if}
	{#if isDependentOfHovered && connectionsEnabled}
		<div class="absolute -right-1 -top-1 h-3 w-3 rounded-full bg-teal-400 ring-2 ring-black"></div>
	{/if}
</button>
