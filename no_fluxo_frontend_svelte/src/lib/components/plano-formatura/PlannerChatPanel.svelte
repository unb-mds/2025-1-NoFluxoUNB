<script lang="ts">
	import { planoFormaturaStore } from '$lib/stores/plano-formatura.store.svelte';
	import { Sparkles, SendHorizontal, Bot } from 'lucide-svelte';
	import { formatHorarioSigaa, compactarFaixasHorarias, formatLocalSigaa } from '$lib/utils/sigaa';
	import ChatWrapper from '$lib/components/chat/ChatWrapper.svelte';
	import ChatBubble from '$lib/components/chat/ChatBubble.svelte';
	import ChatLoader from '$lib/components/chat/ChatLoader.svelte';
	import { authStore } from '$lib/stores/auth';

	let messageInput = $state('');
	let inputRef: HTMLInputElement;

	let authState = $derived($authStore);
	const semestreAtual = $derived(authState.user?.dadosFluxograma?.semestreAtual ?? 1);

	const promptStarters = $derived.by(() => {
		const starters = [];
		const plano = planoFormaturaStore.plano;
		
		if (!plano || !plano.plano || plano.plano.length === 0) {
			// Fallbacks
			starters.push({ prefix: 'Como', badge: 'antecipar', suffix: 'minha formatura?', message: 'Como posso antecipar minha formatura?' });
			starters.push({ prefix: 'Quais as turmas', badge: 'disponíveis?', suffix: '', message: 'Mostre as turmas ofertadas esse semestre' });
			return starters;
		}

		// 1. Semestre mais pesado (misturando créditos + dificuldades)
		const calcPeso = (s: any) => {
			return s.creditos + s.materias.reduce((acc: number, m: any) => acc + (m.dificuldadeEstimada || 5), 0);
		};
		const heaviest = plano.plano.reduce((prev, curr) => (calcPeso(prev) > calcPeso(curr) ? prev : curr));
		if (heaviest && (calcPeso(heaviest) >= 30 || heaviest.creditos >= 20)) {
			const num = semestreAtual + heaviest.indice + 1;
			starters.push({ 
				prefix: 'Semestre', 
				badge: `${num}`,
				suffix: 'tá muito pesado',
				message: `O Semestre ${num} tá muito pesado, tem como dar uma aliviada?` 
			});
		} else {
			starters.push({ prefix: 'Como', badge: 'antecipar', suffix: 'minha formatura?', message: 'Como posso antecipar minha formatura?' });
		}

		// 2. Turmas de uma matéria crítica
		const criticas = plano.plano.flatMap(s => s.materias).filter(m => 'critica' in m && m.critica);
		if (criticas.length > 0) {
			const m = criticas[0] as any;
			starters.push({
				prefix: 'Ver turmas de',
				badge: m.codigo,
				suffix: '',
				message: `/turmas ${m.codigo}`
			});
		} else {
			starters.push({ prefix: 'Buscar', badge: 'turmas disponíveis', suffix: '', message: 'Mostre turmas com vagas sobrando' });
		}

		// 3. Adiar matéria próxima
		const primeiraMat = plano.plano[0].materias.find(m => 'codigo' in m);
		if (primeiraMat) {
			const m = primeiraMat as any;
			starters.push({
				prefix: 'Adiar a matéria',
				badge: m.codigo,
				suffix: '',
				message: `Adie a matéria ${m.codigo} para o próximo semestre`
			});
		}

		// 4. Perguntas Gerais Fixas
		starters.push({ prefix: 'Como posso', badge: 'adiantar', suffix: 'o curso?', message: 'Como posso antecipar minha formatura?' });
		starters.push({ prefix: 'Tem como', badge: 'reduzir', suffix: 'a carga global?', message: 'Tem como reduzir a carga de créditos do meu plano?' });

		// Remover duplicatas caso tenham sido adicionadas nos fallbacks acima (ex: heaviest == false)
		const uniqueStarters = Array.from(new Map(starters.map(item => [item.message, item])).values());

		return uniqueStarters.slice(0, 4);
	});

	function parseMessage(text: string) {
		// O prompt pede texto puro, mas o LLM escapa e manda **negrito** — sem tratar
		// aqui, os asteriscos apareceriam literais na bolha.
		const regex = /(\b[A-Z]{3,4}\d{4}\b)|(\[TURMA\|([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)\|([^\]]+)\])|(\[BOTAO\|([^|\]]+)(?:\|([^\]]+))?\])|(\*\*([^*\n]+)\*\*)/g;
		const blocks: any[] = [];
		let currentBubble: any[] = [];
		let lastIndex = 0;
		let match;
		
		function flushBubble() {
			if (currentBubble.length > 0) {
				const hasContent = currentBubble.some(s => s.type === 'badge' || s.type === 'bold' || (s.type === 'text' && s.value.trim() !== ''));
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
						vagas: match[7].trim()
					}
				});
			} else if (match[8]) {
				flushBubble();
				blocks.push({
					type: 'button',
					label: match[9].trim().replace(/([a-z])([A-Z])/g, '$1 $2'),
					message: match[9].trim() // Ignorando match[10] para evitar alucinações da IA
				});
			} else if (match[11]) {
				// Negrito é inline: fica na bolha atual, sem flush.
				currentBubble.push({ type: 'bold', value: match[12] });
			}
			lastIndex = regex.lastIndex;
		}
		
		if (lastIndex < text.length) {
			currentBubble.push({ type: 'text', value: text.substring(lastIndex) });
		}
		flushBubble();
		
		// Agrupar botões consecutivos para ficarem lado a lado
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

	let chatViewport = $state<HTMLElement | null>(null);

	$effect(() => {
		const msgs = planoFormaturaStore.chatMessages.length;
		const loading = planoFormaturaStore.chatLoading;
		
		if (msgs > 0 || loading) {
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
	<div class="chat-drag-handle relative z-10 px-5 py-4 border-b border-white/5 flex items-center justify-between shrink-0 bg-black/20 backdrop-blur-xl cursor-move select-none">
		<div class="flex items-center gap-3 pointer-events-none">
			<div class="flex items-center justify-center w-8 h-8 rounded-full bg-white/10 shadow-inner border border-white/10">
				<Bot class="h-4 w-4 text-white" />
			</div>
			<h2 class="text-base font-semibold tracking-tight text-white/95">Darcy AI</h2>
		</div>
	</div>

	<div class="relative z-10 flex-1 flex flex-col p-0 overflow-hidden">
		<!-- Mensagens -->
		<div
			class="flex-1 p-5 space-y-4 overflow-y-auto"
			bind:this={chatViewport}
		>
			{#if planoFormaturaStore.chatMessages.length === 0}
				<div class="flex flex-col items-center text-center px-2 sm:px-6 relative z-10 w-full pt-8 pb-4">
					<div class="flex flex-col items-center w-full">
						<div class="w-16 h-16 rounded-3xl bg-pink-500/10 border border-pink-500/50 flex items-center justify-center mb-4 shadow-[0_0_30px_rgba(236,72,153,0.15)] backdrop-blur-md shrink-0">
							<Bot class="h-8 w-8 text-pink-400" />
						</div>
						<h3 class="text-xl font-semibold text-white tracking-tight">Pergunte à nossa IA</h3>
						<p class="text-[12px] text-white/50 mt-2 max-w-[280px] leading-relaxed">
							Dica: Eu posso <span class="font-bold text-indigo-200 drop-shadow-[0_0_6px_rgba(129,140,248,0.8)]">adiar</span>, <span class="font-bold text-indigo-200 drop-shadow-[0_0_6px_rgba(129,140,248,0.8)]">antecipar</span> ou <span class="font-bold text-indigo-200 drop-shadow-[0_0_6px_rgba(129,140,248,0.8)]">remanejar</span> qualquer disciplina do seu plano. Pode pedir!
						</p>
						
						<div class="mt-6 flex flex-wrap justify-center gap-2 w-full max-w-[340px]">
							{#each promptStarters as starter}
								<button 
									type="button" 
									onclick={() => { messageInput = starter.message; enviarMensagem(); }}
									class="group flex items-center px-3 py-1.5 bg-white/5 hover:bg-white/10 border border-white/10 hover:border-indigo-500/40 backdrop-blur-md rounded-full text-[12px] font-medium text-white/80 transition-all cursor-pointer shadow-sm hover:shadow-[0_0_15px_rgba(99,102,241,0.15)] hover:text-white shrink-0"
								>
								<Sparkles class="w-3 h-3 mr-1.5 text-white/30 group-hover:text-indigo-400 transition-colors shrink-0" />
								<div class="flex-1 leading-snug">
									{starter.prefix} 
									{#if starter.badge}
										<span class="inline-flex items-center rounded-full bg-white/5 border border-white/20 px-1.5 py-px text-[10px] font-mono font-bold tracking-wide text-white mx-1 transition-all duration-300 group-hover:bg-indigo-500/20 group-hover:text-indigo-200 group-hover:border-indigo-400/80 group-hover:shadow-[0_0_12px_rgba(129,140,248,0.5),inset_0_0_8px_rgba(129,140,248,0.3)]">{starter.badge}</span>
									{/if}
									{starter.suffix}
								</div>
							</button>
						{/each}
					</div>
				</div>
			</div>
			{:else}
				{#each planoFormaturaStore.chatMessages as msg (msg)}
					{#each parseMessage(msg.content) as block, i}
						{#if block.type === 'bubble'}
							<ChatBubble role={msg.role} name={i === 0 ? (msg.role === 'user' ? 'Você' : 'Darcy AI') : undefined}>
								{#each block.segments as segment}
									{#if segment.type === 'badge'}
										<span class="inline-flex items-center rounded-md bg-white/10 px-1.5 py-0.5 text-xs font-mono font-bold tracking-wide text-white border border-white/20 mx-0.5 shadow-sm backdrop-blur-md">{segment.value}</span>
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
									<span class="text-xl font-black text-white tracking-tight">Turma {block.value.turma}</span>
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
										onclick={() => { messageInput = btn.message; enviarMensagem(); }}
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
						{/if}
					{/each}
				{/each}

				{#if planoFormaturaStore.chatLoading}
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
					placeholder="Ex: Adie Física 1 para o próximo semestre..."
					disabled={planoFormaturaStore.chatLoading}
					onkeydown={handleKeydown}
					class="w-full bg-white/10 backdrop-blur-2xl border border-white/20 rounded-full pl-5 pr-12 py-3.5 text-[14.5px] text-white placeholder:text-white/50 focus:outline-none focus:border-white/30 focus:bg-white/15 transition-all shadow-inner disabled:opacity-50"
				/>
				<button
					type="button"
					onclick={enviarMensagem}
					disabled={planoFormaturaStore.chatLoading || messageInput.trim() === ''}
					class="absolute right-2 p-2 rounded-full bg-white/10 text-white hover:bg-white/20 disabled:opacity-30 disabled:hover:bg-transparent disabled:hover:text-white/40 transition-all cursor-pointer border border-white/10 shadow-sm"
					aria-label="Enviar"
				>
					<SendHorizontal class="w-4 h-4" />
				</button>
			</div>
		</div>
	</div>
</ChatWrapper>
