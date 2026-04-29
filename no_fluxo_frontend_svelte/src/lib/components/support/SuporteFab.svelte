<script lang="ts">
	import { goto } from '$app/navigation';
	import * as Dialog from '$lib/components/ui/dialog';
	import { ROUTES } from '$lib/config/routes';
	import { ticketService } from '$lib/services/ticket.service';
	import { authStore } from '$lib/stores/auth';
	import {
		CATEGORY_LABELS,
		type TicketCategory
	} from '$lib/types/ticket';
	import {
		AlertTriangle,
		Bug,
		CheckCircle2,
		Loader2,
		Paperclip,
		Send,
		X
	} from 'lucide-svelte';
	import { get } from 'svelte/store';

	let open = $state(false);

	let title = $state('');
	let description = $state('');
	let category = $state<TicketCategory>('bug');
	let files = $state<File[]>([]);

	let submitting = $state(false);
	let submitError = $state<string | null>(null);
	let createdId = $state<number | null>(null);

	const MAX_FILES = 3;
	const MAX_FILE_SIZE = 8 * 1024 * 1024;
	const CATEGORIES: TicketCategory[] = ['bug', 'sugestao', 'duvida'];

	function resetForm() {
		title = '';
		description = '';
		category = 'bug';
		files = [];
		submitError = null;
		createdId = null;
	}

	function onOpenChange(next: boolean) {
		open = next;
		if (!next) {
			setTimeout(resetForm, 200);
		} else {
			const state = get(authStore);
			if (!state.isAuthenticated || !state.user) {
				open = false;
				goto(`${ROUTES.LOGIN}?redirect=${encodeURIComponent('/suporte')}`);
			}
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
			createdId = created.id;
		} catch (e) {
			submitError = e instanceof Error ? e.message : 'Erro ao enviar ticket.';
		} finally {
			submitting = false;
		}
	}
</script>

<!-- FAB -->
<button
	type="button"
	class="suporte-fab"
	aria-label="Suporte"
	onclick={() => onOpenChange(true)}
>
	<Bug class="h-6 w-6" />
	<span class="fab-tooltip">Suporte</span>
</button>

<Dialog.Root {open} onOpenChange={onOpenChange}>
	<Dialog.Content
		class="sm:max-w-lg bg-[#0f0a1a] border-white/10 text-white"
		showCloseButton={true}
	>
		<Dialog.Header>
			<Dialog.Title class="flex items-center gap-2 text-white">
				<Bug class="h-5 w-5 text-pink-400" />
				<span>Abrir ticket de suporte</span>
			</Dialog.Title>
			<Dialog.Description class="text-white/60">
				Relate um bug, envie uma sugestão ou tire uma dúvida.
			</Dialog.Description>
		</Dialog.Header>

		{#if createdId !== null}
			<div class="success-state">
				<CheckCircle2 class="h-10 w-10 text-emerald-400" />
				<h3>Ticket #{createdId} enviado</h3>
				<p>Nosso time vai analisar. Você pode acompanhar o status em "Meus tickets".</p>
				<div class="success-actions">
					<button type="button" class="btn-secondary" onclick={() => (createdId = null, resetForm())}>
						Abrir outro
					</button>
					<button
						type="button"
						class="btn-primary"
						onclick={() => {
							open = false;
							goto(ROUTES.SUPORTE);
						}}
					>
						Ver meus tickets
					</button>
				</div>
			</div>
		{:else}
			<form class="form" onsubmit={onSubmit}>
				<div class="field">
					<span class="label">Categoria</span>
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
					<label for="fab-ticket-title" class="label">Título</label>
					<input
						id="fab-ticket-title"
						type="text"
						class="input"
						placeholder="Resumo curto (ex: Fluxograma não carrega no Firefox)"
						maxlength={120}
						bind:value={title}
					/>
				</div>

				<div class="field">
					<label for="fab-ticket-description" class="label">Descrição</label>
					<textarea
						id="fab-ticket-description"
						class="textarea"
						placeholder={category === 'bug'
							? 'Descreva o problema: o que você fez, o que esperava, e o que aconteceu.'
							: category === 'sugestao'
								? 'Conte sua ideia: qual problema ela resolve e como imagina que funcionaria.'
								: 'Faça sua pergunta com o máximo de contexto possível.'}
						rows={5}
						bind:value={description}
					></textarea>
				</div>

				<div class="field">
					<label for="fab-ticket-attachments" class="label">
						Anexos <span class="label-hint">(opcional, até {MAX_FILES}, 8 MB cada)</span>
					</label>
					<label class="upload-trigger" for="fab-ticket-attachments">
						<Paperclip class="h-4 w-4" />
						<span>Selecionar arquivos</span>
						<input
							id="fab-ticket-attachments"
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
					<div class="alert">
						<AlertTriangle class="h-4 w-4 shrink-0" />
						<span>{submitError}</span>
					</div>
				{/if}

				<div class="actions">
					<button
						type="button"
						class="btn-secondary"
						onclick={() => onOpenChange(false)}
						disabled={submitting}
					>
						Cancelar
					</button>
					<button type="submit" class="btn-primary" disabled={submitting}>
						{#if submitting}
							<Loader2 class="h-4 w-4 animate-spin" />
							<span>Enviando…</span>
						{:else}
							<Send class="h-4 w-4" />
							<span>Enviar</span>
						{/if}
					</button>
				</div>
			</form>
		{/if}
	</Dialog.Content>
</Dialog.Root>

<style>
	.suporte-fab {
		position: fixed;
		right: 20px;
		bottom: 20px;
		z-index: 40;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 52px;
		height: 52px;
		border-radius: 50%;
		border: 1px solid rgba(255, 255, 255, 0.15);
		background: linear-gradient(135deg, #9333ea, #ec4899);
		color: white;
		cursor: pointer;
		box-shadow: 0 8px 20px rgba(147, 51, 234, 0.35);
		transition: transform 150ms ease, box-shadow 150ms ease;
	}
	.suporte-fab:hover {
		transform: translateY(-2px);
		box-shadow: 0 12px 28px rgba(236, 72, 153, 0.45);
	}
	.suporte-fab:focus-visible {
		outline: 2px solid #c4b5fd;
		outline-offset: 3px;
	}
	.fab-tooltip {
		position: absolute;
		right: calc(100% + 10px);
		top: 50%;
		transform: translateY(-50%);
		background: rgba(15, 10, 26, 0.95);
		color: white;
		font-size: 12px;
		font-weight: 600;
		padding: 6px 10px;
		border-radius: 6px;
		border: 1px solid rgba(255, 255, 255, 0.12);
		white-space: nowrap;
		pointer-events: none;
		opacity: 0;
		transform: translate(8px, -50%);
		transition: opacity 150ms ease, transform 150ms ease;
	}
	.suporte-fab:hover .fab-tooltip,
	.suporte-fab:focus-visible .fab-tooltip {
		opacity: 1;
		transform: translate(0, -50%);
	}

	@media (max-width: 640px) {
		.suporte-fab {
			right: 16px;
			bottom: 16px;
			width: 48px;
			height: 48px;
		}
		.fab-tooltip {
			display: none;
		}
	}

	.form {
		display: flex;
		flex-direction: column;
		gap: 14px;
	}
	.field {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.label {
		font-size: 12px;
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
		padding: 9px 11px;
		font-size: 13px;
		font-family: inherit;
		width: 100%;
	}
	.input:focus,
	.textarea:focus {
		outline: none;
		border-color: #c4b5fd;
	}
	.textarea {
		resize: vertical;
		min-height: 100px;
	}
	.category-row {
		display: flex;
		gap: 6px;
		flex-wrap: wrap;
	}
	.cat-chip {
		padding: 6px 12px;
		border-radius: 999px;
		border: 1px solid rgba(255, 255, 255, 0.15);
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
		cursor: pointer;
	}
	.cat-chip:hover {
		background: rgba(255, 255, 255, 0.08);
	}
	.cat-chip.active {
		background: rgba(147, 51, 234, 0.3);
		border-color: rgba(147, 51, 234, 0.6);
		color: white;
	}
	.upload-trigger {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 7px 12px;
		border-radius: 6px;
		border: 1px dashed rgba(255, 255, 255, 0.25);
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.75);
		font-size: 12px;
		cursor: pointer;
		width: fit-content;
	}
	.hidden {
		display: none;
	}
	.file-list {
		list-style: none;
		padding: 0;
		margin: 4px 0 0;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}
	.file-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 5px 9px;
		background: rgba(255, 255, 255, 0.04);
		border-radius: 5px;
		font-size: 11px;
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
	}
	.file-remove:hover {
		color: #f87171;
	}
	.alert {
		display: flex;
		gap: 8px;
		padding: 9px 11px;
		border-radius: 6px;
		font-size: 12px;
		background: rgba(239, 68, 68, 0.1);
		border: 1px solid rgba(239, 68, 68, 0.3);
		color: #fca5a5;
	}
	.actions {
		display: flex;
		gap: 8px;
		justify-content: flex-end;
		margin-top: 4px;
	}
	.btn-primary,
	.btn-secondary {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
		padding: 8px 14px;
		border-radius: 6px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		border: 1px solid transparent;
		transition: transform 120ms, opacity 150ms;
	}
	.btn-primary {
		background: linear-gradient(90deg, #9333ea, #ec4899);
		color: white;
	}
	.btn-primary:hover:not(:disabled) {
		transform: translateY(-1px);
	}
	.btn-primary:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
	.btn-secondary {
		background: rgba(255, 255, 255, 0.05);
		border-color: rgba(255, 255, 255, 0.15);
		color: white;
	}
	.btn-secondary:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.1);
	}
	.success-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		padding: 18px 0 8px;
		text-align: center;
	}
	.success-state h3 {
		color: white;
		font-size: 16px;
		font-weight: 700;
		margin: 0;
	}
	.success-state p {
		color: rgba(255, 255, 255, 0.65);
		font-size: 13px;
		margin: 0;
	}
	.success-actions {
		display: flex;
		gap: 8px;
		margin-top: 8px;
	}
</style>
