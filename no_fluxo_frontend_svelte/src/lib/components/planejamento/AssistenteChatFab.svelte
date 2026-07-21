<script lang="ts">
	import ChatPanel from '$lib/components/chat/ChatPanel.svelte';
	import { assistenteChatStore } from '$lib/stores/assistente-chat.store.svelte';
	import { Bot, X, RefreshCw } from 'lucide-svelte';
	import { scale } from 'svelte/transition';
	import { backOut, cubicOut } from 'svelte/easing';

	// Botão flutuante do chatbot (mesmo padrão do Plano de Formatura), embutindo o
	// Darcy com contexto 'montador' — recomenda só matérias com turma — e o botão
	// "+ grade" nos códigos, que insere a matéria no pool via onAddToGrade.
	let {
		onAddToGrade,
		onMontarGrade
	}: {
		onAddToGrade: (codigo: string) => void;
		onMontarGrade: (codigos: string[], turnos?: string[]) => void;
	} = $props();

	let isChatOpen = $state(false);
	let chatW = $state(384);
	let chatH = $state(550);
	let chatX = $state(0);
	let chatY = $state(0);
	let chatPositioned = $state(false);
	let isMobile = $state(false);

	$effect(() => {
		if (typeof window !== 'undefined') {
			const checkMobile = () => (isMobile = window.innerWidth < 768);
			checkMobile();
			window.addEventListener('resize', checkMobile);
			return () => window.removeEventListener('resize', checkMobile);
		}
	});

	function resetChat() {
		chatW = 384;
		chatH = 550;
		chatX = window.innerWidth - chatW - 24;
		chatY = window.innerHeight - chatH - 24;
	}

	$effect(() => {
		if (isChatOpen && !chatPositioned && typeof window !== 'undefined') {
			resetChat();
			chatPositioned = true;
		}
	});

	function draggable(node: HTMLElement) {
		let x = 0;
		let y = 0;

		function handleMousedown(e: MouseEvent) {
			if (isMobile) return;
			const target = e.target as HTMLElement;
			if (!target.closest('.chat-drag-handle')) return;
			x = e.clientX;
			y = e.clientY;
			window.addEventListener('mousemove', handleMousemove);
			window.addEventListener('mouseup', handleMouseup);
		}
		function handleMousemove(e: MouseEvent) {
			chatX += e.clientX - x;
			chatY += e.clientY - y;
			x = e.clientX;
			y = e.clientY;
		}
		function handleMouseup() {
			window.removeEventListener('mousemove', handleMousemove);
			window.removeEventListener('mouseup', handleMouseup);
		}

		node.addEventListener('mousedown', handleMousedown);
		const ro = new ResizeObserver((entries) => {
			for (const entry of entries) {
				if (entry.target === node) {
					chatW = (entry.target as HTMLElement).offsetWidth;
					chatH = (entry.target as HTMLElement).offsetHeight;
				}
			}
		});
		ro.observe(node);

		return {
			destroy() {
				node.removeEventListener('mousedown', handleMousedown);
				ro.disconnect();
			}
		};
	}

	const promptStarters = [
		{ prefix: 'Recomenda', badge: 'optativas', suffix: 'sobre um tema', message: 'Recomende optativas sobre inteligência artificial' },
		{ prefix: 'Optativas mais', badge: 'tranquilas', suffix: '', message: 'Quais optativas mais tranquilas para o próximo semestre?' },
		{ prefix: 'Ver turmas de', badge: 'uma matéria', suffix: '', message: 'Quais as turmas de MAT0025?' }
	];

	function onSend(msg: string) {
		assistenteChatStore.enviarMensagem(msg, { contexto: 'montador' });
	}
</script>

<!-- Painel flutuante -->
{#if isChatOpen}
	<div
		class="fixed z-[100] flex flex-col overflow-hidden border border-white/10 bg-[#090c12]/90 shadow-[0_8px_30px_rgb(0,0,0,0.5)] backdrop-blur-3xl sm:bg-[#090c12]/60
			{isMobile ? 'bottom-0 left-0 right-0 h-[85vh] w-full rounded-t-3xl' : 'origin-bottom-right rounded-2xl'}"
		style={isMobile ? '' : `left: ${chatX}px; top: ${chatY}px; width: ${chatW}px; height: ${chatH}px; resize: both;`}
		use:draggable
		in:scale={{ start: 0.6, duration: 400, easing: backOut }}
		out:scale={{ start: 0.8, duration: 200, easing: cubicOut }}
	>
		<div class="absolute right-4 top-4 z-50 flex items-center gap-1">
			{#if !isMobile}
				<button
					type="button"
					onclick={resetChat}
					class="rounded-md p-1 text-white/40 transition-colors hover:bg-white/5 hover:text-white/80"
					aria-label="Restaurar tamanho e posição"
					title="Restaurar tamanho e posição"
				>
					<RefreshCw class="h-4 w-4" />
				</button>
			{/if}
			<button
				type="button"
				onclick={() => (isChatOpen = false)}
				class="rounded-md p-1 text-white/40 transition-colors hover:bg-white/5 hover:text-white/80"
				aria-label="Fechar chat"
			>
				<X class="h-4 w-4" />
			</button>
		</div>

		<ChatPanel
			messages={assistenteChatStore.chatMessages}
			loading={assistenteChatStore.chatLoading}
			{promptStarters}
			draggable={true}
			title="Darcy AI"
			assistantName="Darcy AI"
			placeholder="Ex: optativas sobre redes com turma aberta..."
			interactiveBadges={true}
			{onSend}
			{onAddToGrade}
			{onMontarGrade}
		>
			{#snippet emptyState()}
				<div class="mb-4 flex h-16 w-16 shrink-0 items-center justify-center rounded-3xl border border-pink-500/50 bg-pink-500/10 shadow-[0_0_30px_rgba(236,72,153,0.15)] backdrop-blur-md">
					<Bot class="h-8 w-8 text-pink-400" />
				</div>
				<h3 class="text-xl font-semibold tracking-tight text-white">Recomende e monte</h3>
				<p class="mt-2 max-w-[280px] text-[12px] leading-relaxed text-white/50">
					Peça optativas por tema — mostro só as que <span class="font-bold text-emerald-200">têm turma</span> neste
					semestre. Toque em <span class="font-bold text-emerald-200">+ grade</span> pra jogar na sua grade.
				</p>
			{/snippet}
		</ChatPanel>
	</div>
{/if}

<!-- Botão flutuante -->
{#if !isChatOpen}
	<button
		type="button"
		onclick={() => (isChatOpen = true)}
		class="fixed z-[90] flex items-center justify-center border border-pink-500/50 bg-[#1e1e24]/80 shadow-[0_8px_30px_rgba(236,72,153,0.3)] backdrop-blur-md transition-all duration-300 hover:scale-105 hover:border-pink-400 hover:bg-[#2a2a32] active:scale-95
			{isMobile ? 'bottom-4 right-4 h-14 w-14 rounded-full' : 'bottom-6 right-6 h-12 w-12 rounded-xl'}"
		aria-label="Abrir assistente IA"
		in:scale={{ start: 0.5, duration: 400, easing: backOut, delay: 100 }}
		out:scale={{ start: 0.5, duration: 200, easing: cubicOut }}
	>
		<Bot class="{isMobile ? 'h-7 w-7' : 'h-6 w-6'} text-pink-400" />
	</button>
{/if}
