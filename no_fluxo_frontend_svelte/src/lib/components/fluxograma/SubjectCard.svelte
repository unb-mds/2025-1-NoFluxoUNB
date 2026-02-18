<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import { SubjectStatusEnum, hasPrerequisites, type SubjectStatusValue } from '$lib/types/materia';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';

	interface Props {
		materia: MateriaModel;
		onclick?: () => void;
		onlongpress?: () => void;
	}

	let { materia, onclick, onlongpress }: Props = $props();

	const store = fluxogramaStore;
	let status = $derived(store.getSubjectStatus(materia));

	let isHovered = $derived(store.state.hoveredSubjectCode === materia.codigoMateria);
	let isSelected = $derived(store.state.selectedSubjectCode === materia.codigoMateria);

	// Check if this subject is a prerequisite of the hovered subject
	let isPrereqOfHovered = $derived.by(() => {
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
		const base = `subject-card relative w-full cursor-pointer rounded-xl border p-3 text-left transition-all duration-200`;
		const borderColor =
			isSelected
				? 'border-white/60 ring-2 ring-white/30'
				: isHighlighted
					? 'border-white/40 shadow-lg'
					: 'border-white/10';
		const dimmed =
			store.state.hoveredSubjectCode && !isHighlighted ? 'opacity-40' : 'opacity-100';
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
		if (!isTouchInteraction) {
			store.setHoveredSubject(materia.codigoMateria);
		}
	}

	function handleMouseLeave() {
		// Don't clear hover on touch devices - it's managed by long-press
		if (!isTouchInteraction) {
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

	function handleTouchStart(e: TouchEvent) {
		isTouchInteraction = true;
		didLongPress = false;
		didDrag = false;
		
		const touch = e.touches[0];
		startX = touch.clientX;
		startY = touch.clientY;

		longPressTimer = setTimeout(() => {
			didLongPress = true;
			// On long-press, show connections (set hover state) and keep them visible
			store.setHoveredSubject(materia.codigoMateria);
			// Also trigger onlongpress callback if not anonymous
			if (!store.state.isAnonymous) {
				onlongpress?.();
			}
		}, 500);
	}

	function handleTouchMove(e: TouchEvent) {
		if (longPressTimer) {
			const touch = e.touches[0];
			const deltaX = Math.abs(touch.clientX - startX);
			const deltaY = Math.abs(touch.clientY - startY);
			
			// If user moved finger, cancel long-press and mark as drag
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
		
		// Only trigger click if it wasn't a drag and wasn't a long-press
		if (!didDrag && !didLongPress) {
			// Clear any previous hover state when clicking a new block
			store.setHoveredSubject(null);
			onclick?.();
		}
		
		didLongPress = false;
		didDrag = false;
		
		// Reset touch interaction flag after a short delay
		// This allows subsequent mouse events to work on hybrid devices
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
		// For non-touch (mouse) interactions, handle click directly
		if (!isTouchInteraction) {
			onclick?.();
		}
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
	<div class="mb-1 flex items-center justify-between gap-1">
		<span class="text-[10px] font-semibold uppercase tracking-wider {textColor} opacity-80">
			{materia.codigoMateria}
		</span>
		<span class="text-[10px] {textColor} opacity-60">
			{materia.creditos}cr
		</span>
	</div>
	<p class="line-clamp-2 text-xs font-medium leading-tight {textColor}">
		{materia.nomeMateria}
	</p>

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

	{#if isPrereqOfHovered}
		<div class="absolute -right-1 -top-1 h-3 w-3 rounded-full bg-purple-400 ring-2 ring-black"></div>
	{/if}
	{#if isDependentOfHovered}
		<div class="absolute -right-1 -top-1 h-3 w-3 rounded-full bg-teal-400 ring-2 ring-black"></div>
	{/if}
</button>
