<script lang="ts">
	import { Handle, Position, type NodeProps } from '@xyflow/svelte';
	import MateriaPlanCard from './MateriaPlanCard.svelte';
	import type { MateriaPlano } from '$lib/types/plano-formatura';

	// Svelte 5 props for xyflow custom node
	let { data }: NodeProps = $props();
	
	const materia = $derived(data.materia as MateriaPlano);
	const tipoSemestre = $derived(data.tipoSemestre as 'recomendado' | 'estimado');
	let hoveredCode = $state<string | null>(null);
</script>

<div class="relative w-[260px]">
	<!-- Target handle (entrada da esquerda) -->
	<Handle
		type="target"
		position={Position.Left}
		style="background: transparent; border: none; width: 1px; height: 1px; left: 0;"
		isConnectable={false}
	/>

	<MateriaPlanCard
		{materia}
		{tipoSemestre}
		bind:hoveredCode={hoveredCode}
	/>

	<!-- Source handle (saída para direita) -->
	<Handle
		type="source"
		position={Position.Right}
		style="background: transparent; border: none; width: 1px; height: 1px; right: 0;"
		isConnectable={false}
	/>
</div>
