<script lang="ts">
	import { type NodeProps } from '@xyflow/svelte';
	import { CalendarDays } from 'lucide-svelte';

	let { data }: NodeProps = $props();
</script>

<div class="flex flex-col items-center justify-center gap-1 w-[260px] rounded-xl border border-white/10 bg-gradient-to-b from-white/5 to-transparent px-4 py-3 shadow-lg backdrop-blur-md">
	<div class="flex items-center justify-center gap-2.5">
		<CalendarDays class="h-5 w-5 text-blue-400 opacity-90" />
		<span class="text-[16px] font-black tracking-wide text-white/90">
			{data.label}
		</span>
	</div>
	{#if data.sublabel}
		<span class="text-[11px] font-semibold tracking-wide text-emerald-300/80">
			{data.sublabel}
		</span>
	{/if}
</div>
