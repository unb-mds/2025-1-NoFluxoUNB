<script lang="ts">
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import PageBackground from '$lib/components/effects/PageBackground.svelte';
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

<PageBackground />

<main
	class="relative z-10 flex min-h-[calc(100vh-64px)] flex-col items-center overflow-hidden px-3 pb-10 sm:px-4 sm:pb-14"
>
	<div
		aria-hidden="true"
		class="pointer-events-none absolute -left-40 -top-40 h-[700px] w-[700px] rounded-full"
		style="background: radial-gradient(circle, rgba(108,38,220,0.32) 0%, rgba(88,22,180,0.13) 42%, transparent 68%); z-index:0;"
	></div>
	<div
		aria-hidden="true"
		class="pointer-events-none absolute -bottom-20 right-0 h-[400px] w-[400px] rounded-full"
		style="background: radial-gradient(circle, rgba(80,20,160,0.18) 0%, transparent 65%); z-index:0;"
	></div>
	<div class="relative z-[1] w-full min-w-0 max-w-2xl">
		<header class="mb-6 text-center sm:mb-9">
			<h1 class="text-3xl font-black tracking-tight text-foreground sm:text-4xl">Importar histórico</h1>
			<p class="mx-auto mt-2 max-w-[480px] text-[15px] text-muted-foreground sm:text-base">
				Envie o PDF do seu histórico oficial da UnB. Os dados são usados só para montar seu fluxograma nesta
				plataforma.
			</p>
		</header>

		<div class="upload-shell">
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
		padding: 1.5rem;
		background: hsl(var(--card));
		border: 1px solid hsl(var(--border) / 0.9);
		border-radius: 20px;
		box-shadow:
			inset 0 1px 0 hsl(0 0% 100% / 0.07),
			inset 1px 0 0 hsl(0 0% 100% / 0.04),
			inset 0 -1px 0 hsl(0 0% 0% / 0.22),
			0 0 0 1px hsl(var(--primary) / 0.08),
			0 24px 48px hsl(0 0% 0% / 0.35);
	}

	@media (min-width: 640px) {
		.upload-shell {
			padding: 2.25rem;
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
