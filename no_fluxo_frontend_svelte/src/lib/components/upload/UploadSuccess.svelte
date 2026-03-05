<script lang="ts">
	import { CheckCircle, RotateCcw, ArrowRight } from 'lucide-svelte';
	import ProcessingResults from './ProcessingResults.svelte';
	import type { CasarDisciplinasResponse, UploadPdfResponse } from '$lib/services/upload.service';

	interface Props {
		data: CasarDisciplinasResponse;
		extractedData?: UploadPdfResponse | null;
		onsave: () => void;
		onreset: () => void;
	}

	let { data, extractedData = null, onsave, onreset }: Props = $props();
</script>

<div class="flex min-w-0 flex-col items-center gap-4 sm:gap-6">
	<!-- Success Header -->
	<div class="success-icon">
		<CheckCircle class="h-10 w-10 text-emerald-400 sm:h-12 sm:w-12" />
	</div>

	<div class="text-center">
		<h3 class="text-lg font-bold text-white sm:text-xl">Processamento concluído!</h3>
		<p class="mt-1 text-xs text-gray-400 sm:text-sm">
			Seu histórico acadêmico foi processado com sucesso.
		</p>
	</div>

	<!-- Results -->
	<div class="w-full min-w-0">
		<ProcessingResults {data} {extractedData} />
	</div>

	<!-- Actions -->
	<div class="flex w-full min-w-0 flex-col gap-2 sm:flex-row sm:justify-center sm:gap-3">
		<button
			type="button"
			class="action-btn primary"
			onclick={onsave}
		>
			<ArrowRight class="h-4 w-4" />
			Visualizar Fluxograma
		</button>

		<button
			type="button"
			class="action-btn secondary"
			onclick={onreset}
		>
			<RotateCcw class="h-4 w-4" />
			Enviar outro PDF
		</button>
	</div>
</div>

<style>
	@reference 'tailwindcss';

	.success-icon {
		@apply flex h-16 w-16 items-center justify-center rounded-full sm:h-20 sm:w-20;
		background: rgba(16, 185, 129, 0.1);
		animation: success-pop 0.4s ease-out;
	}

	.action-btn {
		@apply flex w-full items-center justify-center gap-2 rounded-lg px-5 py-2.5 text-sm font-medium transition-all duration-200 sm:w-auto sm:px-6 sm:py-3;
	}

	.action-btn.primary {
		@apply text-white;
		background: linear-gradient(135deg, #6c63ff, #e91e63);
	}

	.action-btn.primary:hover {
		@apply scale-[1.02];
		box-shadow: 0 4px 15px rgba(108, 99, 255, 0.3);
	}

	.action-btn.secondary {
		@apply border border-white/10 text-gray-300;
		background: rgba(255, 255, 255, 0.05);
	}

	.action-btn.secondary:hover {
		@apply border-white/20 bg-white/10;
	}

	@keyframes success-pop {
		0% {
			transform: scale(0.5);
			opacity: 0;
		}
		70% {
			transform: scale(1.1);
		}
		100% {
			transform: scale(1);
			opacity: 1;
		}
	}
</style>
