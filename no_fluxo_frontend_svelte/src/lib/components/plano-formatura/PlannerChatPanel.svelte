<script lang="ts">
	import { planoFormaturaStore } from '$lib/stores/plano-formatura.store.svelte';
	import Button from '$lib/components/ui/button/button.svelte';
	import Input from '$lib/components/ui/input/input.svelte';
	import ScrollArea from '$lib/components/ui/scroll-area/scroll-area.svelte';
	import { Card, CardContent } from '$lib/components/ui/card';
	import { Sparkles, SendHorizontal, Bot } from 'lucide-svelte';
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import RestricoesChips from './RestricoesChips.svelte';

	let messageInput = $state('');
	let inputRef: HTMLInputElement;

	type TextSegment = { type: 'text' | 'badge', value: string };

	function parseMessage(text: string): TextSegment[] {
		const regex = /\b[A-Z]{3,4}\d{4}\b/g;
		const segments: TextSegment[] = [];
		let lastIndex = 0;
		let match;
		
		while ((match = regex.exec(text)) !== null) {
			if (match.index > lastIndex) {
				segments.push({ type: 'text', value: text.substring(lastIndex, match.index) });
			}
			segments.push({ type: 'badge', value: match[0] });
			lastIndex = regex.lastIndex;
		}
		
		if (lastIndex < text.length) {
			segments.push({ type: 'text', value: text.substring(lastIndex) });
		}
		
		return segments;
	}

	async function enviarMensagem() {
		if (messageInput.trim() === '' || planoFormaturaStore.chatLoading) return;
		const msg = messageInput.trim();
		messageInput = '';
		await planoFormaturaStore.enviarMensagem(msg);
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Enter' && !event.shiftKey) {
			event.preventDefault();
			enviarMensagem();
		}
	}

	$effect(() => {
		// Observa o tamanho do array de mensagens
		if (planoFormaturaStore.chatMessages.length >= 0) {
			setTimeout(() => {
				const chatContainer = document.querySelector('[data-chat-messages]');
				if (chatContainer) chatContainer.scrollTop = chatContainer.scrollHeight;
			}, 10);
		}
	});
</script>

<Card class="flex flex-col h-full border-none bg-transparent rounded-none shadow-none text-white overflow-hidden">
	<!-- Header -->
	<div class="px-4 py-3.5 border-b border-white/5 flex items-center justify-between shrink-0 bg-[#090c12]">
		<div class="flex items-center gap-2">
			<Bot class="h-4 w-4 text-blue-400" />
			<h2 class="text-[13px] font-semibold text-white/90">Assistente Darcy</h2>
		</div>
		<Badge variant="outline" class="border-blue-500/20 bg-blue-500/10 text-blue-300 text-[10px] font-medium uppercase tracking-wider px-2 py-0.5 rounded-full shadow-sm">
			Darcy AI
		</Badge>
	</div>
	<CardContent class="flex-1 flex flex-col p-0 overflow-hidden">
		<!-- Mensagens -->
		<ScrollArea
			class="flex-1 p-4 space-y-3 overflow-y-auto"
			data-chat-messages
		>
			{#if planoFormaturaStore.chatMessages.length === 0}
				<div class="flex flex-col items-center justify-center h-full text-center px-6 mt-8 mb-8">
					<Sparkles class="h-8 w-8 mb-4 text-white/50" />
					<h3 class="text-lg font-medium text-white/90">Pergunte à nossa IA</h3>
					
					<div class="mt-8 flex flex-col gap-2 w-full max-w-[260px]">
						<p class="text-[10px] font-semibold text-white/30 uppercase tracking-wider text-left mb-1">Sugestões do que perguntar</p>
						<button 
							type="button" 
							onclick={() => { messageInput = 'Como posso antecipar minha formatura?'; enviarMensagem(); }}
							class="text-left px-3.5 py-2.5 bg-[#1e1e24] hover:bg-[#2a2a32] border border-white/5 rounded-xl text-[13px] text-white/70 transition-all cursor-pointer"
						>
							Como posso antecipar minha formatura?
						</button>
						<button 
							type="button" 
							onclick={() => { messageInput = 'Quais são as matérias críticas do curso?'; enviarMensagem(); }}
							class="text-left px-3.5 py-2.5 bg-[#1e1e24] hover:bg-[#2a2a32] border border-white/5 rounded-xl text-[13px] text-white/70 transition-all cursor-pointer"
						>
							Quais são as matérias críticas?
						</button>
					</div>
				</div>
			{:else}
				{#each planoFormaturaStore.chatMessages as msg (msg)}
					<div class={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
						<div
							class={`max-w-[85%] px-3.5 py-2.5 text-[13px] leading-relaxed ${
								msg.role === 'user'
									? 'bg-[#1e1e24] text-white/90 rounded-2xl rounded-tr-sm border border-white/5'
									: 'bg-transparent text-white/80 rounded-2xl rounded-tl-sm'
							}`}
						>
							{#each parseMessage(msg.content) as segment}
								{#if segment.type === 'badge'}
									<span class="inline-flex items-center rounded bg-[#1e1e24] px-1.5 py-0.5 text-xs font-mono font-bold tracking-wide text-blue-300 border border-blue-500/30 mx-0.5 shadow-sm">{segment.value}</span>
								{:else}
									<span class="whitespace-pre-wrap">{segment.value}</span>
								{/if}
							{/each}
						</div>
					</div>
				{/each}

				{#if planoFormaturaStore.chatLoading}
					<div class="flex justify-start items-center gap-3 mt-1 mb-2 ml-2">
						<div class="liquid-loader shrink-0 shadow-lg">
							<div class="liquid-blob-1"></div>
							<div class="liquid-blob-2"></div>
							<Sparkles class="w-3.5 h-3.5 text-white/90 z-10 animate-pulse" />
						</div>
						<span class="text-[13px] text-white/50 animate-pulse font-medium">Pensando...</span>
					</div>
				{/if}
			{/if}
		</ScrollArea>

		<!-- Restrições ativas -->
		{#if planoFormaturaStore.restricoes.adiar.length > 0 || planoFormaturaStore.restricoes.priorizar.length > 0}
			<div class="px-4 py-3 border-t border-white/5">
				<p class="text-[11px] font-semibold text-white/40 uppercase tracking-wider mb-2">Restrições ativas:</p>
				<RestricoesChips />
			</div>
		{/if}

		<!-- Input -->
		<div class="p-4 pt-2 bg-transparent">
			<div class="relative flex items-center w-full">
				<input
					type="text"
					bind:value={messageInput}
					bind:this={inputRef}
					placeholder="Pergunte qualquer coisa..."
					disabled={planoFormaturaStore.chatLoading}
					onkeydown={handleKeydown}
					class="w-full bg-[#1e1e24] border border-white/5 rounded-2xl pl-4 pr-12 py-3.5 text-[13px] text-white/90 placeholder:text-white/30 focus:outline-none focus:border-white/10 focus:ring-1 focus:ring-white/10 transition-all disabled:opacity-50"
				/>
				<button
					type="button"
					onclick={enviarMensagem}
					disabled={planoFormaturaStore.chatLoading || messageInput.trim() === ''}
					class="absolute right-2 p-2 rounded-xl text-white/40 hover:text-white/90 hover:bg-white/10 disabled:opacity-30 disabled:hover:bg-transparent disabled:hover:text-white/40 transition-colors cursor-pointer"
					aria-label="Enviar"
				>
					<SendHorizontal class="w-4 h-4" />
				</button>
			</div>
		</div>
	</CardContent>
</Card>

<style>
	.liquid-loader {
		position: relative;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		overflow: hidden;
		background-color: #090c12; /* Preto de fundo */
		border: 1px solid rgba(255, 255, 255, 0.05);
	}
	.liquid-blob-1 {
		position: absolute;
		width: 24px;
		height: 24px;
		background: #8b5cf6; /* Roxo claro */
		border-radius: 40% 60% 70% 30% / 40% 50% 60% 50%;
		animation: liquidMix 3s linear infinite;
		filter: blur(5px);
		mix-blend-mode: screen;
		opacity: 0.8;
	}
	.liquid-blob-2 {
		position: absolute;
		width: 24px;
		height: 24px;
		background: #c026d3; /* Fucsia / Roxo escuro */
		border-radius: 60% 40% 30% 70% / 60% 30% 70% 40%;
		animation: liquidMixReverse 4s linear infinite;
		filter: blur(5px);
		mix-blend-mode: screen;
		opacity: 0.8;
	}
	@keyframes liquidMix {
		0% { transform: rotate(0deg) scale(1) translate(-2px, -2px); }
		50% { transform: rotate(180deg) scale(1.3) translate(2px, 2px); }
		100% { transform: rotate(360deg) scale(1) translate(-2px, -2px); }
	}
	@keyframes liquidMixReverse {
		0% { transform: rotate(360deg) scale(1.3) translate(2px, -2px); }
		50% { transform: rotate(180deg) scale(1) translate(-2px, 2px); }
		100% { transform: rotate(0deg) scale(1.3) translate(2px, -2px); }
	}
</style>
