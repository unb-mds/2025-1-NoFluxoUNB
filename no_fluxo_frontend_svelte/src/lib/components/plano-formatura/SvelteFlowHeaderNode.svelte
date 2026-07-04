<script lang="ts">
	import { type NodeProps } from '@xyflow/svelte';
	import { CalendarDays } from 'lucide-svelte';

	let { data }: NodeProps = $props();
</script>

<div class="flex items-center justify-center gap-2.5 w-[260px] rounded-xl border border-white/10 bg-gradient-to-b from-white/5 to-transparent px-4 py-3.5 shadow-lg backdrop-blur-md">
	<CalendarDays class="h-5 w-5 text-blue-400 opacity-90" />
	<span class="text-[16px] font-black tracking-wide text-white/90">
		{data.label}
	</span>
</div>
