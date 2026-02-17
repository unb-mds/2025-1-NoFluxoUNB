<script lang="ts">
	import { Upload, FileText } from 'lucide-svelte';
	import { validatePdfFile, formatFileSize } from '$lib/utils/fileValidation';
	import { toast } from 'svelte-sonner';

	interface Props {
		onfileselected: (file: File) => void;
		disabled?: boolean;
	}

	let { onfileselected, disabled = false }: Props = $props();

	let isDragging = $state(false);
	let fileInput: HTMLInputElement | undefined = $state();

	function handleDragEnter(e: DragEvent) {
		e.preventDefault();
		if (!disabled) isDragging = true;
	}

	function handleDragOver(e: DragEvent) {
		e.preventDefault();
		if (!disabled) isDragging = true;
	}

	function handleDragLeave(e: DragEvent) {
		e.preventDefault();
		isDragging = false;
	}

	function handleDrop(e: DragEvent) {
		e.preventDefault();
		isDragging = false;
		if (disabled) return;

		const file = e.dataTransfer?.files[0];
		if (file) processFile(file);
	}

	function handleFileSelect(e: Event) {
		const target = e.target as HTMLInputElement;
		const file = target.files?.[0];
		if (file) processFile(file);
		// Reset input so the same file can be selected again
		if (target) target.value = '';
	}

	function processFile(file: File) {
		const validation = validatePdfFile(file);
		if (!validation.valid) {
			toast.error(validation.error ?? 'Arquivo inválido.');
			return;
		}
		onfileselected(file);
	}

	function openFilePicker() {
		if (!disabled) fileInput?.click();
	}

	function handleKeydown(e: KeyboardEvent) {
		if ((e.key === 'Enter' || e.key === ' ') && !disabled) {
			e.preventDefault();
			openFilePicker();
		}
	}
</script>

<div
	class="dropzone"
	class:dragging={isDragging}
	class:disabled
	role="button"
	tabindex={disabled ? -1 : 0}
	ondragenter={handleDragEnter}
	ondragover={handleDragOver}
	ondragleave={handleDragLeave}
	ondrop={handleDrop}
	onclick={openFilePicker}
	onkeydown={handleKeydown}
	aria-label="Área para arrastar e soltar arquivo PDF"
>
	<input
		bind:this={fileInput}
		type="file"
		accept=".pdf,application/pdf"
		class="hidden"
		onchange={handleFileSelect}
		{disabled}
	/>

	<div class="icon-container" class:pulse={isDragging}>
		{#if isDragging}
			<FileText class="h-12 w-12 text-purple-400" />
		{:else}
			<Upload class="h-12 w-12 text-gray-400" />
		{/if}
	</div>

	<p class="mt-4 text-lg font-medium text-white">
		{#if isDragging}
			Solte o arquivo aqui
		{:else}
			Arraste seu histórico em PDF aqui
		{/if}
	</p>

	<div class="divider">
		<span class="divider-line"></span>
		<span class="divider-text">ou</span>
		<span class="divider-line"></span>
	</div>

	<button
		type="button"
		class="select-btn"
		tabindex={-1}
		disabled={disabled}
	>
		Selecionar Arquivo
	</button>

	<p class="mt-3 text-sm text-gray-500">
		Somente arquivos PDF são aceitos (máx. 10MB)
	</p>
</div>

<style>
	@reference 'tailwindcss';

	.dropzone {
		@apply relative flex flex-col items-center justify-center rounded-2xl border-2 border-dashed border-gray-600 p-10 transition-all duration-300 cursor-pointer;
		background: rgba(255, 255, 255, 0.03);
		min-height: 280px;
	}

	.dropzone:hover:not(.disabled) {
		@apply border-purple-500/60;
		background: rgba(139, 92, 246, 0.05);
	}

	.dropzone:focus-visible {
		@apply outline-none ring-2 ring-purple-500 ring-offset-2 ring-offset-black;
	}

	.dropzone.dragging {
		@apply border-purple-400 bg-purple-500/10;
		box-shadow: 0 0 30px rgba(139, 92, 246, 0.15);
	}

	.dropzone.disabled {
		@apply cursor-not-allowed opacity-50;
	}

	.icon-container {
		@apply flex h-20 w-20 items-center justify-center rounded-full transition-all duration-300;
		background: rgba(139, 92, 246, 0.1);
	}

	.icon-container.pulse {
		animation: pulse-glow 1.5s ease-in-out infinite;
	}

	.divider {
		@apply my-4 flex w-full items-center gap-3;
		max-width: 200px;
	}

	.divider-line {
		@apply h-px flex-1 bg-gray-700;
	}

	.divider-text {
		@apply text-sm text-gray-500;
	}

	.select-btn {
		@apply rounded-lg px-6 py-2.5 text-sm font-medium text-white transition-all duration-200;
		background: linear-gradient(135deg, #6c63ff, #e91e63);
	}

	.select-btn:hover:not(:disabled) {
		@apply scale-105;
		box-shadow: 0 4px 15px rgba(108, 99, 255, 0.3);
	}

	.select-btn:disabled {
		@apply cursor-not-allowed opacity-50;
	}

	@keyframes pulse-glow {
		0%, 100% {
			box-shadow: 0 0 10px rgba(139, 92, 246, 0.2);
		}
		50% {
			box-shadow: 0 0 25px rgba(139, 92, 246, 0.4);
		}
	}
</style>
