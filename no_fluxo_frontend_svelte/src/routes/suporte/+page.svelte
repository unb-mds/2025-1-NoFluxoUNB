<script lang="ts">
	import { onMount } from 'svelte';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import { authStore } from '$lib/stores/auth';
	import { goto } from '$app/navigation';
	import { ROUTES } from '$lib/config/routes';
	import { ticketService } from '$lib/services/ticket.service';
	import {
		CATEGORY_COLORS,
		CATEGORY_LABELS,
		STATUS_COLORS,
		STATUS_LABELS,
		type Ticket,
		type TicketCategory
	} from '$lib/types/ticket';
	import { AlertTriangle, CheckCircle2, Loader2, Paperclip, Plus, Send, X } from 'lucide-svelte';

	type Tab = 'novo' | 'meus';

	let activeTab = $state<Tab>('novo');

	let title = $state('');
	let description = $state('');
	let category = $state<TicketCategory>('bug');
	let files = $state<File[]>([]);
	let submitting = $state(false);
	let submitError = $state<string | null>(null);
	let justCreatedId = $state<number | null>(null);

	let myTickets = $state<Ticket[]>([]);
	let loadingList = $state(false);
	let listError = $state<string | null>(null);

	const MAX_FILES = 3;
	const MAX_FILE_SIZE = 8 * 1024 * 1024; // 8 MB
	const CATEGORIES: TicketCategory[] = ['bug', 'sugestao', 'duvida'];

	onMount(() => {
		const state = $authStore;
		if (!state.isAuthenticated || !state.user) {
			goto(`${ROUTES.LOGIN}?redirect=${encodeURIComponent('/suporte')}`);
			return;
		}
		void loadMyTickets();
	});

	async function loadMyTickets() {
		loadingList = true;
		listError = null;
		try {
			myTickets = await ticketService.listMyTickets();
		} catch (e) {
			listError = e instanceof Error ? e.message : 'Erro ao carregar seus tickets.';
		} finally {
			loadingList = false;
		}
	}

	function onFileSelect(event: Event) {
		const target = event.target as HTMLInputElement;
		const selected = Array.from(target.files ?? []);
		const valid: File[] = [];
		for (const f of selected) {
			if (f.size > MAX_FILE_SIZE) {
				submitError = `Arquivo "${f.name}" excede 8 MB.`;
				continue;
			}
			valid.push(f);
		}
		files = [...files, ...valid].slice(0, MAX_FILES);
		target.value = '';
	}

	function removeFile(idx: number) {
		files = files.filter((_, i) => i !== idx);
	}

	async function onSubmit(e: Event) {
		e.preventDefault();
		submitError = null;
		if (title.trim().length < 4) {
			submitError = 'O título precisa ter ao menos 4 caracteres.';
			return;
		}
		if (description.trim().length < 10) {
			submitError = 'A descrição precisa ter ao menos 10 caracteres.';
			return;
		}
		submitting = true;
		try {
			const created = await ticketService.createTicket({
				title,
				description,
				category,
				attachments: files
			});
			justCreatedId = created.id;
			title = '';
			description = '';
			category = 'bug';
			files = [];
			activeTab = 'meus';
			await loadMyTickets();
		} catch (e) {
			submitError = e instanceof Error ? e.message : 'Erro ao enviar ticket.';
		} finally {
			submitting = false;
		}
	}

	function formatDate(value: string): string {
		try {
			return new Date(value).toLocaleString('pt-BR', {
				day: '2-digit',
				month: 'short',
				year: 'numeric',
				hour: '2-digit',
				minute: '2-digit'
			});
		} catch {
			return value;
		}
	}
</script>

<PageMeta
	title="Suporte"
	description="Relate bugs, envie sugestões ou tire dúvidas sobre o NoFluxoUNB."
/>

<AnimatedBackground />

<main class="relative z-10 flex min-h-[calc(100vh-64px)] flex-col items-center px-3 py-6 sm:px-4 sm:py-10">
	<div class="w-full max-w-3xl">
		<div class="mb-6 text-center sm:mb-8">
			<h1 class="text-2xl font-bold text-white sm:text-3xl">Suporte</h1>
			<p class="mt-1.5 text-sm text-gray-400 sm:text-base">
				Relate um bug, envie uma sugestão ou tire uma dúvida. Nosso time técnico vai analisar.
			</p>
		</div>

		<div class="mb-5 flex gap-2 border-b border-white/10">
			<button
				type="button"
				class="tab-btn"
				class:active={activeTab === 'novo'}
				onclick={() => (activeTab = 'novo')}
			>
				<Plus class="h-4 w-4" />
				<span>Novo ticket</span>
			</button>
			<button
				type="button"
				class="tab-btn"
				class:active={activeTab === 'meus'}
				onclick={() => {
					activeTab = 'meus';
					void loadMyTickets();
				}}
			>
				<span>Meus tickets</span>
				{#if myTickets.length > 0}
					<span class="badge-count">{myTickets.length}</span>
				{/if}
			</button>
		</div>

		{#if activeTab === 'novo'}
			<form class="card" onsubmit={onSubmit}>
				<div class="field">
					<label for="ticket-category" class="label">Categoria</label>
					<div class="category-row">
						{#each CATEGORIES as cat}
							<button
								type="button"
								class="cat-chip"
								class:active={category === cat}
								onclick={() => (category = cat)}
							>
								{CATEGORY_LABELS[cat]}
							</button>
						{/each}
					</div>
				</div>

				<div class="field">
					<label for="ticket-title" class="label">Título</label>
					<input
						id="ticket-title"
						type="text"
						class="input"
						placeholder="Resumo curto (ex: Fluxograma não carrega no Firefox)"
						maxlength={120}
						bind:value={title}
					/>
				</div>

				<div class="field">
					<label for="ticket-description" class="label">Descrição</label>
					<textarea
						id="ticket-description"
						class="textarea"
						placeholder={category === 'bug'
							? 'Descreva o problema: o que você fez, o que esperava, e o que aconteceu. Adicione prints se possível.'
							: category === 'sugestao'
								? 'Conte sua ideia: qual problema ela resolve e como imagina que funcionaria.'
								: 'Faça sua pergunta com o máximo de contexto possível.'}
						rows={6}
						bind:value={description}
					></textarea>
				</div>

				<div class="field">
					<label for="ticket-attachments" class="label">
						Anexos <span class="label-hint">(opcional, até {MAX_FILES} arquivos, 8 MB cada)</span>
					</label>
					<label class="upload-trigger" for="ticket-attachments">
						<Paperclip class="h-4 w-4" />
						<span>Selecionar arquivos</span>
						<input
							id="ticket-attachments"
							type="file"
							class="hidden"
							multiple
							accept="image/*,.pdf,.txt,.log"
							onchange={onFileSelect}
						/>
					</label>
					{#if files.length > 0}
						<ul class="file-list">
							{#each files as f, i}
								<li class="file-item">
									<Paperclip class="h-3.5 w-3.5" />
									<span class="truncate">{f.name}</span>
									<span class="file-size">{(f.size / 1024).toFixed(0)} KB</span>
									<button
										type="button"
										class="file-remove"
										aria-label="Remover anexo"
										onclick={() => removeFile(i)}
									>
										<X class="h-3.5 w-3.5" />
									</button>
								</li>
							{/each}
						</ul>
					{/if}
				</div>

				{#if submitError}
					<div class="alert alert-error">
						<AlertTriangle class="h-4 w-4 shrink-0" />
						<span>{submitError}</span>
					</div>
				{/if}

				{#if justCreatedId}
					<div class="alert alert-success">
						<CheckCircle2 class="h-4 w-4 shrink-0" />
						<span>Ticket #{justCreatedId} enviado. Acompanhe em "Meus tickets".</span>
					</div>
				{/if}

				<button type="submit" class="submit-btn" disabled={submitting}>
					{#if submitting}
						<Loader2 class="h-4 w-4 animate-spin" />
						<span>Enviando…</span>
					{:else}
						<Send class="h-4 w-4" />
						<span>Enviar ticket</span>
					{/if}
				</button>
			</form>
		{:else}
			<div class="space-y-3">
				{#if loadingList}
					<div class="card loading">
						<Loader2 class="h-5 w-5 animate-spin" />
						<span>Carregando seus tickets…</span>
					</div>
				{:else if listError}
					<div class="alert alert-error">
						<AlertTriangle class="h-4 w-4 shrink-0" />
						<span>{listError}</span>
					</div>
				{:else if myTickets.length === 0}
					<div class="card empty">
						<p>Você ainda não abriu nenhum ticket.</p>
						<button class="link-btn" onclick={() => (activeTab = 'novo')}>Abrir o primeiro →</button>
					</div>
				{:else}
					{#each myTickets as t (t.id)}
						<article class="ticket-card">
							<div class="ticket-header">
								<span class="ticket-id">#{t.id}</span>
								<span class="chip {CATEGORY_COLORS[t.category]}">{CATEGORY_LABELS[t.category]}</span>
								<span class="chip {STATUS_COLORS[t.status]}">{STATUS_LABELS[t.status]}</span>
								<span class="ticket-date">{formatDate(t.created_at)}</span>
							</div>
							<h3 class="ticket-title">{t.title}</h3>
							<p class="ticket-desc">{t.description}</p>
							{#if t.attachments && t.attachments.length > 0}
								<div class="ticket-attachments">
									<Paperclip class="h-3.5 w-3.5" />
									<span>{t.attachments.length} anexo{t.attachments.length > 1 ? 's' : ''}</span>
								</div>
							{/if}
						</article>
					{/each}
				{/if}
			</div>
		{/if}
	</div>
</main>

<style>
	.tab-btn {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 10px 14px;
		background: transparent;
		border: none;
		border-bottom: 2px solid transparent;
		color: rgba(255, 255, 255, 0.6);
		font-weight: 500;
		cursor: pointer;
		transition: color 150ms, border-color 150ms;
		font-size: 14px;
	}
	.tab-btn:hover {
		color: white;
	}
	.tab-btn.active {
		color: white;
		border-bottom-color: #9333ea;
	}
	.badge-count {
		background: rgba(147, 51, 234, 0.2);
		color: #e9d5ff;
		border-radius: 9999px;
		padding: 1px 8px;
		font-size: 11px;
		font-weight: 600;
	}

	.card {
		display: flex;
		flex-direction: column;
		gap: 18px;
		background: rgba(255, 255, 255, 0.03);
		backdrop-filter: blur(10px);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 12px;
		padding: 22px;
	}
	.card.loading,
	.card.empty {
		align-items: center;
		justify-content: center;
		gap: 10px;
		color: rgba(255, 255, 255, 0.7);
		min-height: 140px;
	}

	.field {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	.label {
		font-size: 13px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}
	.label-hint {
		font-weight: 400;
		color: rgba(255, 255, 255, 0.5);
	}

	.input,
	.textarea {
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.12);
		border-radius: 8px;
		color: white;
		padding: 10px 12px;
		font-size: 14px;
		font-family: inherit;
		transition: border-color 150ms;
		width: 100%;
	}
	.input:focus,
	.textarea:focus {
		outline: none;
		border-color: #9333ea;
	}
	.textarea {
		resize: vertical;
		min-height: 120px;
	}

	.category-row {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}
	.cat-chip {
		padding: 8px 14px;
		border-radius: 999px;
		border: 1px solid rgba(255, 255, 255, 0.15);
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.8);
		font-size: 13px;
		cursor: pointer;
		transition: all 150ms;
	}
	.cat-chip:hover {
		background: rgba(255, 255, 255, 0.08);
	}
	.cat-chip.active {
		background: rgba(147, 51, 234, 0.25);
		border-color: rgba(147, 51, 234, 0.6);
		color: white;
	}

	.upload-trigger {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 8px 14px;
		border-radius: 8px;
		border: 1px dashed rgba(255, 255, 255, 0.25);
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.75);
		font-size: 13px;
		cursor: pointer;
		width: fit-content;
	}
	.upload-trigger:hover {
		background: rgba(255, 255, 255, 0.06);
		color: white;
	}
	.hidden {
		display: none;
	}

	.file-list {
		list-style: none;
		padding: 0;
		margin: 6px 0 0;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.file-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 6px 10px;
		background: rgba(255, 255, 255, 0.04);
		border-radius: 6px;
		font-size: 12px;
		color: rgba(255, 255, 255, 0.8);
	}
	.file-size {
		margin-left: auto;
		color: rgba(255, 255, 255, 0.5);
	}
	.file-remove {
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.6);
		cursor: pointer;
		padding: 2px;
		border-radius: 4px;
	}
	.file-remove:hover {
		color: #f87171;
	}

	.alert {
		display: flex;
		gap: 10px;
		padding: 10px 12px;
		border-radius: 8px;
		font-size: 13px;
		border: 1px solid transparent;
	}
	.alert-error {
		background: rgba(239, 68, 68, 0.1);
		border-color: rgba(239, 68, 68, 0.3);
		color: #fca5a5;
	}
	.alert-success {
		background: rgba(16, 185, 129, 0.1);
		border-color: rgba(16, 185, 129, 0.3);
		color: #6ee7b7;
	}

	.submit-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		padding: 11px 18px;
		border-radius: 8px;
		border: none;
		background: linear-gradient(90deg, #9333ea, #ec4899);
		color: white;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		transition: transform 120ms, opacity 150ms;
	}
	.submit-btn:hover:not(:disabled) {
		transform: translateY(-1px);
	}
	.submit-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.link-btn {
		background: none;
		border: none;
		color: #c4b5fd;
		cursor: pointer;
		font-weight: 500;
		padding: 0;
	}
	.link-btn:hover {
		color: #e9d5ff;
	}

	.ticket-card {
		background: rgba(255, 255, 255, 0.03);
		backdrop-filter: blur(10px);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 10px;
		padding: 16px 18px;
	}
	.ticket-header {
		display: flex;
		align-items: center;
		gap: 8px;
		flex-wrap: wrap;
		margin-bottom: 8px;
	}
	.ticket-id {
		font-family: 'JetBrains Mono', monospace;
		color: rgba(255, 255, 255, 0.55);
		font-size: 12px;
	}
	.chip {
		display: inline-flex;
		padding: 2px 8px;
		font-size: 11px;
		font-weight: 600;
		border-radius: 4px;
		border: 1px solid;
	}
	.ticket-date {
		margin-left: auto;
		font-size: 11px;
		color: rgba(255, 255, 255, 0.45);
	}
	.ticket-title {
		color: white;
		font-size: 15px;
		font-weight: 600;
		margin: 0 0 4px;
	}
	.ticket-desc {
		color: rgba(255, 255, 255, 0.65);
		font-size: 13px;
		margin: 0;
		display: -webkit-box;
		-webkit-line-clamp: 3;
		line-clamp: 3;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
	.ticket-attachments {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		margin-top: 8px;
		font-size: 11px;
		color: rgba(255, 255, 255, 0.5);
	}
</style>
