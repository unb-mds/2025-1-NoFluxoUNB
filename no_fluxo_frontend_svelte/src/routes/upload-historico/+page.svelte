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
	import { AlertTriangle, RotateCcw } from 'lucide-svelte';

	let showHelp = $state(false);
</script>

<PageMeta
	title="Importar Histórico"
	description="Faça upload do seu histórico acadêmico em PDF para gerar seu fluxograma"
	noIndex={true}
/>

<AnimatedBackground />

<main
	class="relative z-10 flex min-h-[calc(100vh-64px)] flex-col items-center overflow-x-hidden px-3 py-6 sm:px-4 sm:py-10"
>
	<div class="w-full min-w-0 max-w-2xl">
		<header class="mb-6 text-center sm:mb-9">
			<h1 class="text-2xl font-bold tracking-tight text-foreground sm:text-3xl">Importar histórico</h1>
			<p class="mt-2 text-sm text-muted-foreground sm:text-base">
				Envie o PDF do seu histórico oficial da UnB. Os dados são usados só para montar seu fluxograma nesta
				plataforma.
			</p>
		</header>

		<div class="upload-shell nf-card-surface">
			{#if $uploadStore.state === 'initial'}
				<FileDropzone onfileselected={(file) => uploadStore.uploadFile(file)} />
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
				<div class="error-state">
					<div class="error-icon">
						<AlertTriangle class="size-10 text-red-400" stroke-width="2" />
					</div>
					<div class="error-copy">
						<h3 class="error-title">Não foi possível processar</h3>
						<p class="error-msg">
							{$uploadStore.error ?? 'Ocorreu um erro inesperado. Verifique o arquivo e tente novamente.'}
						</p>
					</div>
					<button type="button" class="retry-btn" onclick={() => uploadStore.reset()}>
						<RotateCcw class="size-4" />
						Tentar novamente
					</button>
				</div>
			{/if}
		</div>

		<div class="mt-6 flex justify-center">
			<HelpButton onclick={() => (showHelp = true)} />
		</div>

		{#if $uploadStore.fileName && $uploadStore.state !== 'initial'}
			<p class="mt-4 text-center text-xs text-muted-foreground">
				Arquivo selecionado: <span class="font-medium text-foreground/90">{$uploadStore.fileName}</span>
			</p>
		{/if}
	</div>
</main>

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
	.upload-shell {
		overflow: hidden;
		padding: 1.15rem;
	}

	@media (min-width: 640px) {
		.upload-shell {
			padding: 2rem;
		}
	}

	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1.15rem;
		padding: 2rem 1rem;
	}

	.error-icon {
		display: flex;
		height: 4rem;
		width: 4rem;
		align-items: center;
		justify-content: center;
		border-radius: 9999px;
		background: hsl(0 72% 51% / 0.1);
		border: 1px solid hsl(0 72% 51% / 0.22);
	}

	.error-copy {
		text-align: center;
	}

	.error-title {
		font-size: 1.0625rem;
		font-weight: 700;
		color: hsl(var(--foreground));
		margin: 0;
	}

	.error-msg {
		margin: 0.35rem auto 0;
		max-width: 22rem;
		font-size: 0.875rem;
		line-height: 1.5;
		color: hsl(var(--muted-foreground));
	}

	.retry-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.45rem;
		padding: 0.55rem 1.15rem;
		border-radius: 12px;
		font-size: 0.875rem;
		font-weight: 600;
		color: hsl(var(--foreground));
		background: hsl(var(--secondary) / 0.55);
		border: 1px solid hsl(0 0% 100% / 0.12);
		cursor: pointer;
		transition:
			background 0.15s ease,
			border-color 0.15s ease;
	}

	.retry-btn:hover {
		background: hsl(var(--secondary) / 0.85);
		border-color: hsl(0 0% 100% / 0.18);
	}
</style>
