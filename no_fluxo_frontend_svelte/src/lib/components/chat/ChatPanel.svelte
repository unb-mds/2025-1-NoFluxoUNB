<script lang="ts">
	import { Sparkles, SendHorizontal, Bot, CalendarPlus } from 'lucide-svelte';
	import { formatHorarioSigaa, compactarFaixasHorarias, formatLocalSigaa } from '$lib/utils/sigaa';
	import ChatWrapper from '$lib/components/chat/ChatWrapper.svelte';
	import ChatBubble from '$lib/components/chat/ChatBubble.svelte';
	import ChatLoader from '$lib/components/chat/ChatLoader.svelte';
	import type { Snippet } from 'svelte';

	interface Starter {
		prefix: string;
		badge?: string;
		suffix?: string;
		message: string;
	}
	interface ChatMsg {
		role: 'user' | 'assistant';
		content: string;
	}

	let {
		messages,
		loading = false,
		promptStarters = [],
		title = 'Darcy AI',
		assistantName = 'Darcy AI',
		placeholder = 'Pergunte alguma coisa...',
		draggable = false,
		interactiveBadges = false,
		onSend,
		onAddToGrade,
		onMontarGrade,
		emptyState
	}: {
		messages: ChatMsg[];
		loading?: boolean;
		promptStarters?: Starter[];
		title?: string;
		assistantName?: string;
		placeholder?: string;
		draggable?: boolean;
		/** Quando true, os códigos de matéria viram botões clicáveis (envia o código). */
		interactiveBadges?: boolean;
		onSend: (msg: string) => void;
		/** Quando definido, cada badge de código ganha um botão "+ grade". */
		onAddToGrade?: (codigo: string) => void;
		/** Quando definido, o marcador [MONTAR_GRADE|COD,...|TURNOS] vira um botão de ação. */
		onMontarGrade?: (codigos: string[], turnos?: string[]) => void;
		emptyState?: Snippet;
	} = $props();

	let messageInput = $state('');
	let inputRef: HTMLInputElement;
	let chatViewport = $state<HTMLElement | null>(null);

	function enviar() {
		if (messageInput.trim() === '' || loading) return;
		const msg = messageInput.trim();
		messageInput = '';
		onSend(msg);
	}

	// Envio direto (botões/badges) — não mexe no que o usuário está digitando.
	function enviarTexto(text: string) {
		if (!text.trim() || loading) return;
		onSend(text.trim());
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Enter' && !event.shiftKey) {
			event.preventDefault();
			enviar();
		}
	}

	// Parser compartilhado: badges de código, blocos [TURMA|...], [BOTAO|...] e **negrito**.
	function parseMessage(text: string) {
		const regex = /(\b[A-Z]{3,4}\d{4}\b)|(\[TURMA\|([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)\|([^|\]]+)(?:\|([^\]]+))?\])|(\[BOTAO\|([^|\]]+)(?:\|([^\]]+))?\])|(\*\*([^*\n]+)\*\*)|(\[MONTAR_GRADE\|([^\]]+)\])/g;
		const blocks: any[] = [];
		let currentBubble: any[] = [];
		let lastIndex = 0;
		let match;

		function flushBubble() {
			if (currentBubble.length > 0) {
				const hasContent = currentBubble.some(
					(s) => s.type === 'badge' || s.type === 'bold' || (s.type === 'text' && s.value.trim() !== '')
				);
				if (hasContent) {
					blocks.push({ type: 'bubble', segments: currentBubble });
				}
				currentBubble = [];
			}
		}

		while ((match = regex.exec(text)) !== null) {
			if (match.index > lastIndex) {
				currentBubble.push({ type: 'text', value: text.substring(lastIndex, match.index) });
			}

			if (match[1]) {
				currentBubble.push({ type: 'badge', value: match[1] });
			} else if (match[2]) {
				flushBubble();
				blocks.push({
					type: 'turma',
					value: {
						turma: match[3].trim(),
						prof: match[4].trim(),
						horario: match[5].trim(),
						local: match[6].trim(),
						vagas: match[7].trim(),
						periodo: match[8] ? match[8].trim() : undefined
					}
				});
			} else if (match[9]) {
				flushBubble();
				blocks.push({
					type: 'button',
					label: match[10].trim().replace(/([a-z])([A-Z])/g, '$1 $2'),
					message: match[11] ? match[11].trim() : match[10].trim()
				});
			} else if (match[12]) {
				currentBubble.push({ type: 'bold', value: match[13] });
			} else if (match[14]) {
				flushBubble();
				// [MONTAR_GRADE|COD1,COD2|M,N] → códigos (1º campo) + turnos (2º, opcional)
				const partes = (match[15] ?? '').split('|');
				const codigos = (partes[0] ?? '')
					.split(',')
					.map((c) => c.trim().toUpperCase())
					.filter(Boolean);
				const turnos = (partes[1] ?? '')
					.split(',')
					.map((t) => t.trim().toUpperCase())
					.filter((t) => t === 'M' || t === 'T' || t === 'N');
				if (codigos.length > 0 || turnos.length > 0)
					blocks.push({ type: 'montarGrade', codigos, turnos });
			}
			lastIndex = regex.lastIndex;
		}

		if (lastIndex < text.length) {
			currentBubble.push({ type: 'text', value: text.substring(lastIndex) });
		}
		flushBubble();

		// Agrupar botões consecutivos para ficarem lado a lado.
		const finalBlocks: any[] = [];
		for (const block of blocks) {
			if (block.type === 'button') {
				const lastBlock = finalBlocks[finalBlocks.length - 1];
				if (lastBlock && lastBlock.type === 'buttonGroup') {
					lastBlock.buttons.push(block);
				} else {
					finalBlocks.push({ type: 'buttonGroup', buttons: [block] });
				}
			} else {
				finalBlocks.push(block);
			}
		}

		return finalBlocks;
	}

	$effect(() => {
		const msgs = messages.length;
		const isLoading = loading;
		if (msgs > 0 || isLoading) {
			setTimeout(() => {
				if (chatViewport) {
					chatViewport.scrollTop = chatViewport.scrollHeight;
				}
			}, 50);
		}
	});
</script>

<ChatWrapper>
	<!-- Header -->
	<div
		class="relative z-10 px-4 py-3 border-b border-white/5 flex items-center shrink-0 bg-black/20 backdrop-blur-xl {draggable ? 'chat-drag-handle cursor-move select-none pr-20' : ''}"
	>
		<div class="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1 shadow-sm backdrop-blur-md max-w-full overflow-hidden">
			<Sparkles class="h-3.5 w-3.5 text-pink-400 shrink-0" />
			<span class="text-[11px] font-bold tracking-[0.16em] text-white uppercase shrink-0">{title.toUpperCase()}</span>
			<span class="text-[10.5px] text-white/40 font-normal truncate min-w-0">Powered by Maritaca AI</span>
		</div>
	</div>

	<div class="relative z-10 flex-1 flex flex-col p-0 overflow-hidden">
		<!-- Mensagens -->
		<div class="flex-1 p-5 space-y-4 overflow-y-auto" bind:this={chatViewport}>
			{#if messages.length === 0}
				<div class="flex flex-col items-center text-center px-2 sm:px-6 relative z-10 w-full pt-8 pb-4">
					<div class="flex flex-col items-center w-full">
						{#if emptyState}
							{@render emptyState()}
						{:else}
							<div class="w-16 h-16 rounded-3xl bg-pink-500/10 border border-pink-500/50 flex items-center justify-center mb-4 shadow-[0_0_30px_rgba(236,72,153,0.15)] backdrop-blur-md shrink-0">
								<Bot class="h-8 w-8 text-pink-400" />
							</div>
							<h3 class="text-xl font-semibold text-white tracking-tight">Pergunte à nossa IA</h3>
						{/if}

						{#if promptStarters.length > 0}
							<div class="mt-6 flex flex-wrap justify-center gap-2 w-full max-w-[340px]">
								{#each promptStarters as starter}
									<button
										type="button"
										onclick={() => { messageInput = starter.message; enviar(); }}
										class="group flex items-center px-3 py-1.5 bg-white/5 hover:bg-white/10 border border-white/10 hover:border-indigo-500/40 backdrop-blur-md rounded-full text-[12px] font-medium text-white/80 transition-all cursor-pointer shadow-sm hover:shadow-[0_0_15px_rgba(99,102,241,0.15)] hover:text-white shrink-0"
									>
										<Sparkles class="w-3 h-3 mr-1.5 text-white/30 group-hover:text-indigo-400 transition-colors shrink-0" />
										<div class="flex-1 leading-snug">
											{starter.prefix}
											{#if starter.badge}
												<span class="inline-flex items-center rounded-full bg-white/5 border border-white/20 px-1.5 py-px text-[10px] font-mono font-bold tracking-wide text-white mx-1 transition-all duration-300 group-hover:bg-indigo-500/20 group-hover:text-indigo-200 group-hover:border-indigo-400/80 group-hover:shadow-[0_0_12px_rgba(129,140,248,0.5),inset_0_0_8px_rgba(129,140,248,0.3)]">{starter.badge}</span>
											{/if}
											{starter.suffix ?? ''}
										</div>
									</button>
								{/each}
							</div>
						{/if}
					</div>
				</div>
			{:else}
				{#each messages as msg (msg)}
					{#each parseMessage(msg.content) as block, i}
						{#if block.type === 'bubble'}
							<ChatBubble role={msg.role} name={i === 0 ? (msg.role === 'user' ? 'Você' : assistantName) : undefined}>
								{#each block.segments as segment}
									{#if segment.type === 'badge'}
										<span class="mx-0.5 inline-flex items-center gap-0.5">
											{#if interactiveBadges}
												<button
													type="button"
													onclick={() => enviarTexto(segment.value)}
													disabled={loading}
													title={`Ver ${segment.value}`}
													class="badge-glow inline-flex items-center rounded-md bg-indigo-500/20 px-1.5 py-0.5 text-xs font-mono font-bold tracking-wide text-white border border-indigo-400/60 backdrop-blur-md cursor-pointer transition-all hover:bg-indigo-500/40 hover:border-indigo-300 hover:-translate-y-px active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
												>{segment.value}</button>
											{:else}
												<span class="inline-flex items-center rounded-md bg-white/10 px-1.5 py-0.5 text-xs font-mono font-bold tracking-wide text-white border border-white/20 shadow-sm backdrop-blur-md">{segment.value}</span>
											{/if}
											{#if onAddToGrade}
												<button
													type="button"
													onclick={() => onAddToGrade?.(segment.value)}
													title={`Adicionar ${segment.value} à grade`}
													class="inline-flex items-center rounded-md border border-emerald-400/50 bg-emerald-500/15 px-1 py-0.5 text-[10px] font-semibold text-emerald-100 transition-colors hover:bg-emerald-500/30 active:scale-95"
												>+ grade</button>
											{/if}
										</span>
									{:else if segment.type === 'bold'}
										<strong class="font-bold text-white">{segment.value}</strong>
									{:else}
										<span class="whitespace-pre-wrap">{segment.value}</span>
									{/if}
								{/each}
							</ChatBubble>
						{:else if block.type === 'turma'}
							<div class="rounded-3xl border border-indigo-500/40 bg-gradient-to-br from-indigo-500/10 to-fuchsia-500/10 backdrop-blur-2xl p-5 my-2 shadow-2xl flex flex-col gap-4 w-[95%] sm:w-[85%] block self-center relative overflow-hidden">
								<div class="absolute -top-10 -right-10 w-32 h-32 bg-indigo-500/30 rounded-full blur-[40px] pointer-events-none"></div>

								<div class="flex flex-wrap items-center justify-between border-b border-indigo-400/20 pb-3 mb-1 gap-2 relative z-10">
									<div class="flex items-center gap-2.5">
										<span class="text-xl font-black text-white tracking-tight">Turma {block.value.turma}</span>
										{#if block.value.periodo}
											<span class="text-indigo-200 text-xs font-bold bg-indigo-500/25 border border-indigo-400/40 px-2.5 py-0.5 rounded-full shadow-sm">{block.value.periodo}</span>
										{/if}
									</div>
									<span class="text-white text-[11px] font-bold tracking-widest bg-indigo-500/30 border border-indigo-400/30 px-3 py-1.5 rounded-full shadow-inner">{block.value.vagas} VAGAS</span>
								</div>

								<div class="space-y-4 relative z-10">
									<div>
										<p class="text-indigo-200 text-[11px] font-bold uppercase tracking-widest mb-1">Professor</p>
										<p class="text-white font-bold text-base drop-shadow-md">{block.value.prof}</p>
									</div>

									<div class="flex flex-col sm:flex-row gap-5 sm:gap-8">
										<div class="flex-1">
											<p class="text-indigo-200 text-[11px] font-bold uppercase tracking-widest mb-1.5">Horário</p>
											{#if formatHorarioSigaa(block.value.horario).length > 0}
												<div class="space-y-1.5">
													{#each formatHorarioSigaa(block.value.horario) as linha}
														<div class="flex items-center gap-3 text-[14px]">
															<span class="text-white font-bold w-8">{linha.dia}</span>
															<span class="text-white/90 font-medium">{compactarFaixasHorarias(linha.faixas)}</span>
														</div>
													{/each}
												</div>
											{:else}
												<p class="text-white/90 font-medium text-[14px]">{block.value.horario}</p>
											{/if}
										</div>

										<div class="flex-1">
											<p class="text-indigo-200 text-[11px] font-bold uppercase tracking-widest mb-1.5">Local</p>
											{#if formatLocalSigaa(block.value.local).length > 0}
												<div class="space-y-1.5">
													{#each formatLocalSigaa(block.value.local) as localLinha}
														<p class="text-white/90 font-medium text-[14px] leading-snug">{localLinha}</p>
													{/each}
												</div>
											{:else}
												<p class="text-white/90 font-medium text-[14px]">{block.value.local}</p>
											{/if}
										</div>
									</div>
								</div>
							</div>
						{:else if block.type === 'buttonGroup'}
							<div class="flex flex-col gap-2 mt-2 ml-10 mr-4 self-start w-[85%]">
								{#each block.buttons as btn}
									<button
										type="button"
										onclick={() => { messageInput = btn.message; enviar(); }}
										class="w-full px-4 py-2.5 text-left rounded-xl text-sm font-medium tracking-wide transition-all shadow-md active:scale-[0.98] cursor-pointer border backdrop-blur-md
											{btn.label.toLowerCase() === 'sim' || btn.label.toLowerCase().includes('aplicar')
												? 'bg-emerald-600/30 text-emerald-50 hover:bg-emerald-600/50 border-emerald-500/40 shadow-[0_0_15px_rgba(16,185,129,0.15)]'
												: btn.label.toLowerCase() === 'não' || btn.label.toLowerCase() === 'nao' || btn.label.toLowerCase().includes('cancelar')
												? 'bg-rose-600/30 text-rose-50 hover:bg-rose-600/50 border-rose-500/40 shadow-[0_0_15px_rgba(244,63,94,0.15)]'
												: 'bg-indigo-600/30 text-indigo-50 hover:bg-indigo-600/50 border-indigo-500/40 shadow-[0_0_15px_rgba(99,102,241,0.15)]'}"
									>
										{btn.label}
									</button>
								{/each}
							</div>
						{:else if block.type === 'montarGrade' && onMontarGrade}
							<div class="mt-2 ml-10 mr-4 self-start w-[85%]">
								<button
									type="button"
									onclick={() => onMontarGrade?.(block.codigos, block.turnos)}
									class="flex w-full items-center gap-2 rounded-xl border border-emerald-500/40 bg-emerald-600/25 px-4 py-2.5 text-left text-sm font-semibold text-emerald-50 shadow-[0_0_15px_rgba(16,185,129,0.15)] backdrop-blur-md transition-all hover:bg-emerald-600/45 active:scale-[0.98]"
								>
									<CalendarPlus class="h-4 w-4 shrink-0" />
									<span>
										Montar grade{#if block.codigos.length > 0} priorizando {block.codigos.join(', ')}{/if}{#if block.turnos.length > 0}
											· {block.turnos.map((t: string) => ({ M: 'manhã', T: 'tarde', N: 'noite' })[t] ?? t).join(' e ')}{/if}
									</span>
								</button>
							</div>
						{/if}
					{/each}
				{/each}

				{#if loading}
					<ChatLoader />
				{/if}
			{/if}
		</div>

		<!-- Input -->
		<div class="p-5 pt-3 bg-transparent relative z-10 pb-6">
			<div class="relative flex items-center w-full shadow-2xl">
				<input
					type="text"
					bind:value={messageInput}
					bind:this={inputRef}
					{placeholder}
					disabled={loading}
					onkeydown={handleKeydown}
					class="w-full bg-white/10 backdrop-blur-2xl border border-white/20 rounded-full pl-5 pr-12 py-3.5 text-[14.5px] text-white placeholder:text-white/50 focus:outline-none focus:border-white/30 focus:bg-white/15 transition-all shadow-inner disabled:opacity-50"
				/>
				<button
					type="button"
					onclick={enviar}
					disabled={loading || messageInput.trim() === ''}
					class="absolute right-2 p-2 rounded-full bg-white/10 text-white hover:bg-white/20 disabled:opacity-30 disabled:hover:bg-transparent disabled:hover:text-white/40 transition-all cursor-pointer border border-white/10 shadow-sm"
					aria-label="Enviar"
				>
					<SendHorizontal class="w-4 h-4" />
				</button>
			</div>
		</div>
	</div>
</ChatWrapper>

<style>
	/* Glow pulsante nos códigos de matéria clicáveis — deixa óbvio que dá pra apertar. */
	.badge-glow {
		box-shadow: 0 0 8px rgba(129, 140, 248, 0.55), inset 0 0 6px rgba(129, 140, 248, 0.25);
		animation: badgePulse 2s ease-in-out infinite;
	}
	.badge-glow:hover {
		animation: none;
		box-shadow: 0 0 18px rgba(129, 140, 248, 0.95), inset 0 0 8px rgba(129, 140, 248, 0.4);
	}
	@keyframes badgePulse {
		0%, 100% {
			box-shadow: 0 0 6px rgba(129, 140, 248, 0.4), inset 0 0 5px rgba(129, 140, 248, 0.2);
		}
		50% {
			box-shadow: 0 0 15px rgba(129, 140, 248, 0.9), inset 0 0 8px rgba(129, 140, 248, 0.4);
		}
	}
	@media (prefers-reduced-motion: reduce) {
		.badge-glow {
			animation: none;
		}
	}
</style>
