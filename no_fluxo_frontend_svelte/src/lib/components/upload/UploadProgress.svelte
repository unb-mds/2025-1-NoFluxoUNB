<script lang="ts">
	import { Loader2 } from 'lucide-svelte';

	interface Props {
		progress: number;
		state: 'uploading' | 'processing';
	}

	let { progress, state }: Props = $props();

	let statusText = $derived(
		state === 'uploading'
			? 'Enviando seu histórico...'
			: 'Processando disciplinas...'
	);
</script>

<div class="flex flex-col items-center gap-6 py-8">
	<div class="spinner-container">
		<Loader2 class="h-10 w-10 animate-spin text-purple-400" />
	</div>

	<div class="text-center">
		<h3 class="text-lg font-semibold text-white">{statusText}</h3>
		<p class="mt-1 text-sm text-gray-400">Isso pode levar alguns segundos</p>
	</div>

	<div class="progress-wrapper">
		<div class="progress-track">
			<div
				class="progress-bar"
				style="width: {progress}%"
			></div>
		</div>
		<span class="progress-text">{progress}%</span>
	</div>
</div>

<style>
	@reference 'tailwindcss';

	.spinner-container {
		@apply flex h-16 w-16 items-center justify-center rounded-full;
		background: rgba(139, 92, 246, 0.1);
	}

	.progress-wrapper {
		@apply flex w-full max-w-xs items-center gap-3;
	}

	.progress-track {
		@apply h-2.5 flex-1 overflow-hidden rounded-full;
		background: rgba(255, 255, 255, 0.1);
	}

	.progress-bar {
		@apply h-full rounded-full transition-all duration-300 ease-out;
		background: linear-gradient(90deg, #6c63ff, #e91e63, #f0c419);
		background-size: 200% 100%;
		animation: gradient-shift 2s ease infinite;
	}

	.progress-text {
		@apply min-w-[3rem] text-right text-sm font-medium text-purple-300;
	}

	@keyframes gradient-shift {
		0% { background-position: 0% 50%; }
		50% { background-position: 100% 50%; }
		100% { background-position: 0% 50%; }
	}
</style>
