<script lang="ts">
	import { type NodeProps } from '@xyflow/svelte';

	let { data }: NodeProps = $props();
</script>

<div class="text-white font-bold text-[14px] w-[260px] text-left">
	{data.label}
</div>
