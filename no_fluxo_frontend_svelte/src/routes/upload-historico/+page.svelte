<script lang="ts">
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import FileDropzone from '$lib/components/upload/FileDropzone.svelte';
	import UploadProgress from '$lib/components/upload/UploadProgress.svelte';
	import UploadSuccess from '$lib/components/upload/UploadSuccess.svelte';
	import HelpButton from '$lib/components/upload/HelpButton.svelte';
	import HelpModal from '$lib/components/upload/HelpModal.svelte';
	import CourseSelectionModal from '$lib/components/upload/CourseSelectionModal.svelte';
	import { uploadStore } from '$lib/stores/uploadStore';
	import { AlertTriangle, RotateCcw, Upload } from 'lucide-svelte';

	let showHelp = $state(false);
</script>

<PageMeta
	title="Importar Histórico"
	description="Faça upload do seu histórico acadêmico em PDF para gerar seu fluxograma"
/>

<AnimatedBackground />

<main class="relative z-10 flex min-h-[calc(100vh-64px)] flex-col items-center px-4 py-10">
	<div class="w-full max-w-2xl">
		<!-- Header -->
		<div class="mb-8 text-center">
			<h1 class="text-3xl font-bold text-white">Importar Histórico</h1>
			<p class="mt-2 text-gray-400">
				Envie seu histórico acadêmico em PDF para gerar seu fluxograma personalizado.
			</p>
		</div>

		<!-- Upload Card -->
		<div class="upload-card">
			{#if $uploadStore.state === 'initial'}
				<FileDropzone
					onfileselected={(file) => uploadStore.uploadFile(file)}
				/>

			{:else if $uploadStore.state === 'uploading' || ($uploadStore.state === 'processing' && !$uploadStore.showCourseSelection)}
				<UploadProgress
					progress={$uploadStore.progress}
					state={$uploadStore.state === 'uploading' ? 'uploading' : 'processing'}
				/>

			{:else if $uploadStore.state === 'success' && $uploadStore.disciplinasCasadas}
				<UploadSuccess
					data={$uploadStore.disciplinasCasadas}
					extractedData={$uploadStore.extractedData}
					onsave={() => uploadStore.saveAndNavigate()}
					onreset={() => uploadStore.reset()}
				/>

			{:else if $uploadStore.state === 'error'}
				<div class="flex flex-col items-center gap-5 py-8">
					<div class="error-icon">
						<AlertTriangle class="h-10 w-10 text-red-400" />
					</div>
					<div class="text-center">
						<h3 class="text-lg font-semibold text-white">Erro ao processar</h3>
						<p class="mt-1 max-w-sm text-sm text-gray-400">
							{$uploadStore.error ?? 'Ocorreu um erro inesperado. Tente novamente.'}
						</p>
					</div>
					<button
						type="button"
						class="retry-btn"
						onclick={() => uploadStore.reset()}
					>
						<RotateCcw class="h-4 w-4" />
						Tentar novamente
					</button>
				</div>
			{/if}
		</div>

		<!-- Help Button -->
		{#if $uploadStore.state === 'initial'}
			<div class="mt-6 flex justify-center">
				<HelpButton onclick={() => (showHelp = true)} />
			</div>
		{/if}

		<!-- File info -->
		{#if $uploadStore.fileName && $uploadStore.state !== 'initial'}
			<p class="mt-4 text-center text-xs text-gray-500">
				Arquivo: {$uploadStore.fileName}
			</p>
		{/if}
	</div>
</main>

<!-- Modals -->
<HelpModal open={showHelp} onclose={() => (showHelp = false)} />

{#if $uploadStore.showCourseSelection && $uploadStore.courseSelectionError}
	<CourseSelectionModal
		open={$uploadStore.showCourseSelection}
		courseError={$uploadStore.courseSelectionError}
		onselect={(courseName, selected) => uploadStore.retryWithSelectedCourse(courseName, selected)}
		onclose={() => uploadStore.dismissCourseSelection()}
	/>
{/if}

<style>
	@reference 'tailwindcss';

	.upload-card {
		@apply overflow-hidden rounded-2xl p-8;
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.08);
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
	}

	.error-icon {
		@apply flex h-16 w-16 items-center justify-center rounded-full;
		background: rgba(239, 68, 68, 0.1);
	}

	.retry-btn {
		@apply flex items-center gap-2 rounded-lg border border-white/10 px-5 py-2.5 text-sm font-medium text-gray-300 transition-all duration-200;
		background: rgba(255, 255, 255, 0.05);
	}

	.retry-btn:hover {
		@apply border-white/20 text-white;
		background: rgba(255, 255, 255, 0.1);
	}
</style>
