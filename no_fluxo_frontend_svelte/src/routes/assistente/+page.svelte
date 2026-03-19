<script lang="ts">
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import { Bot, Send, Loader2, Sparkles } from 'lucide-svelte';
	import { AssistenteService, type StreamEvent } from '$lib/services/assistente.service';
	import { fly } from 'svelte/transition';

	let mensagem = '';
	let carregando = false;
	let etapaAtual = '';
	let historico: Array<{ tipo: 'usuario' | 'assistente', texto: string, disciplinas?: any[] }> = [];

	const assistente = new AssistenteService();

	async function enviarMensagem() {
		if (!mensagem.trim() || carregando) return;

		const mensagemUsuario = mensagem.trim();
		mensagem = '';

		// Adiciona mensagem do usuário ao histórico
		historico = [...historico, { tipo: 'usuario', texto: mensagemUsuario }];

		carregando = true;
		etapaAtual = 'Conectando...';

		// Add a placeholder assistant message that will be updated progressively
		const assistenteIndex = historico.length;
		historico = [...historico, { tipo: 'assistente', texto: '', disciplinas: [] }];

		try {
			await assistente.streamMessageFromSabia(mensagemUsuario, (event: StreamEvent) => {
				switch (event.stage) {
					case 'thinking':
						etapaAtual = event.message || 'Analisando...';
						break;
					case 'searching':
						etapaAtual = event.message || 'Buscando disciplinas...';
						break;
					case 'generating':
						etapaAtual = event.message || 'Gerando recomendações...';
						break;
					case 'disciplina':
						if (event.data) {
							const current = historico[assistenteIndex];
							const disciplinas = [...(current.disciplinas || []), event.data];
							historico[assistenteIndex] = { ...current, disciplinas };
							historico = historico; // trigger reactivity
						}
						break;
					case 'done':
						historico[assistenteIndex] = {
							...historico[assistenteIndex],
							texto: event.resultado || 'Resposta recebida'
						};
						historico = historico;
						break;
					case 'error':
						historico[assistenteIndex] = {
							tipo: 'assistente',
							texto: `❌ Erro: ${event.message}`,
							disciplinas: undefined
						};
						historico = historico;
						break;
				}
			});
		} catch (erro: any) {
			// If the placeholder was added but streaming failed entirely
			historico[assistenteIndex] = {
				tipo: 'assistente',
				texto: `❌ Erro ao conectar: ${erro.message}`,
				disciplinas: undefined
			};
			historico = historico;
		} finally {
			carregando = false;
			etapaAtual = '';
		}
	}

	function handleKeyPress(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			enviarMensagem();
		}
	}
</script>

<PageMeta
	title="Darcy AI"
	description="Converse com o assistente inteligente do NoFluxo para descobrir disciplinas"
/>

<AnimatedBackground />

<div class="relative z-10 container mx-auto max-w-5xl px-3 py-4 sm:px-4 sm:py-8 h-[calc(100vh-88px)] sm:h-[calc(100vh-100px)] flex flex-col">
	<!-- Header -->
	<div class="mb-6">
		<div class="flex items-center gap-3">
			<div class="flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-br from-pink-500 to-purple-600">
				<Sparkles class="h-6 w-6 text-white" />
			</div>
			<div>
				<h1 class="text-2xl font-bold text-white">Darcy AI</h1>
				<p class="text-gray-300 text-sm">Powered by Maritaca AI</p>
			</div>
		</div>
	</div>

	<!-- Banner de orientações -->
	<div class="mb-3 sm:mb-4 rounded-xl border border-white/10 bg-black/40 px-3 py-2.5 sm:px-4 sm:py-3 text-xs sm:text-sm text-gray-200">
		<p class="font-semibold text-gray-100 mb-0.5 sm:mb-1">Como usar o Darcy AI</p>
		<p class="text-gray-300">
			Envie só <span class="font-semibold">tópicos de interesse</span> (ex.: "IA e visão computacional"). Evite papo paralelo:
			perguntas diretas geram <span class="font-semibold">melhores sugestões de disciplinas</span>.
		</p>
	</div>

	<!-- Chat Container -->
	<div class="flex-1 chat-shell rounded-2xl overflow-hidden flex flex-col">
		<!-- Mensagens -->
		<div class="flex-1 overflow-y-auto p-6 space-y-4">
			{#if historico.length === 0}
				<div class="h-full flex flex-col items-center justify-center text-center">
					<Bot class="h-16 w-16 text-pink-400 mb-4 opacity-50" />
					<h2 class="text-xl font-semibold text-white mb-2">Como posso ajudar?</h2>
					<div class="mt-6 grid grid-cols-2 sm:grid-cols-3 gap-2 sm:gap-3 max-w-2xl">
					<button
						on:click={() => { mensagem = 'Direito Constitucional e Teoria da Constituição'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">⚖️ Direito Constitucional</p>
					</button>

					<button
						on:click={() => { mensagem = 'História da África: Sociedades Pré-Coloniais e Processos de Independência'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">🌍 História da África</p>
					</button>

					<button
						on:click={() => { mensagem = 'Inteligência Artificial: Aprendizado de Máquina e Redes Neurais'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">🤖 Inteligência Artificial</p>
					</button>

					<button
						on:click={() => { mensagem = 'Bioética e Saúde Coletiva no Sistema Único de Saúde'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">🦠 Microbiologia</p>
					</button>

					<button
						on:click={() => { mensagem = 'Macroeconomia: Modelos de Crescimento e Políticas Monetárias'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">📈 Macroeconomia</p>
					</button>

					<button
						on:click={() => { mensagem = 'Cálculo Diferencial e Integral para Engenharia'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">⚛️ Física Quântica</p>
					</button>
				</div>
				</div>
			{:else}
				{#each historico as msg}
					<div class="flex {msg.tipo === 'usuario' ? 'justify-end' : 'justify-start'}">
						<div class="max-w-[80%]">
							{#if msg.tipo === 'usuario'}
								<div class="bg-gradient-to-br from-pink-500 to-purple-600 text-white rounded-2xl px-4 py-3">
									<p class="whitespace-pre-wrap">{msg.texto}</p>
								</div>
							{:else}
								<div class="assistant-bubble rounded-2xl px-4 py-3">
									<!-- Só mostra o texto se NÃO houver disciplinas -->
									{#if !msg.disciplinas || msg.disciplinas.length === 0}
										<p class="text-white whitespace-pre-wrap">{msg.texto}</p>
									{/if}
									
									{#if msg.disciplinas && msg.disciplinas.length > 0}
										<!-- Título apenas para disciplinas -->
										<p class="text-white font-semibold mb-3">
											🎓 {msg.disciplinas.length} {msg.disciplinas.length === 1 ? 'disciplina encontrada' : 'disciplinas encontradas'}
										</p>
										<div class="mt-4 space-y-2">
											{#each msg.disciplinas as disc (disc.codigo)}
												<div class="assistant-card rounded-lg p-3" transition:fly={{ y: 20, duration: 300 }}>
													<div class="flex items-start justify-between gap-2">
														<div class="flex-1">
															<p class="text-pink-400 font-semibold text-sm">{disc.codigo}</p>
															<p class="text-white font-medium">{disc.nome}</p>
															{#if disc.justificativa}
																<p class="text-gray-400 text-sm mt-1">{disc.justificativa}</p>
															{/if}
														</div>
														<div class="flex items-center gap-1 text-yellow-400">
															<span class="text-lg font-bold">{disc.nota}</span>
															<span class="text-xs">/10</span>
														</div>
													</div>
												</div>
											{/each}
										</div>
									{/if}
								</div>
							{/if}
						</div>
					</div>
				{/each}
			{/if}
			
			{#if carregando}
				<div class="flex justify-start">
					<div class="assistant-bubble rounded-2xl px-4 py-3">
						<div class="flex items-center gap-2 text-gray-400">
							<Loader2 class="h-4 w-4 animate-spin" />
							<span>{etapaAtual || 'Pensando...'}</span>
						</div>
					</div>
				</div>
			{/if}
		</div>

		<!-- Input -->
		<div class="border-t border-white/10 p-2.5 sm:p-3">
			<form on:submit|preventDefault={enviarMensagem} class="flex gap-1.5 items-center">
				<input
					type="text"
					bind:value={mensagem}
					on:keypress={handleKeyPress}
					placeholder="Só tópicos de interesse (ex: IA aplicada a saúde)..."
					disabled={carregando}
					class="flex-1 bg-black/50 border border-white/20 rounded-full px-3 py-2.5 text-sm text-white placeholder-gray-300 focus:outline-none focus:ring-2 focus:ring-pink-500/50 disabled:opacity-50"
				/>
				<button
					type="submit"
					disabled={!mensagem.trim() || carregando}
					class="shrink-0 bg-gradient-to-br from-pink-500 to-purple-600 text-white rounded-full px-3 sm:px-4 py-2 text-sm font-medium hover:opacity-90 transition-opacity disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-1.5 shadow-md shadow-pink-500/30"
				>
					{#if carregando}
						<Loader2 class="h-5 w-5 animate-spin" />
					{:else}
						<Send class="h-5 w-5" />
					{/if}
					<span class="hidden sm:inline">Enviar</span>
				</button>
			</form>
		</div>
	</div>
</div>

<style>
	.chat-shell {
		background: rgba(15, 23, 42, 0.72);
		border: 1px solid rgba(255, 255, 255, 0.14);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
	}

	.chat-suggestion {
		background: rgba(15, 23, 42, 0.58);
		border: 1px solid rgba(255, 255, 255, 0.14);
		color: rgba(255, 255, 255, 0.96);
	}

	.chat-suggestion:hover {
		background: rgba(30, 41, 59, 0.78);
		border-color: rgba(255, 255, 255, 0.24);
	}

	.assistant-bubble {
		background: rgba(15, 23, 42, 0.82);
		border: 1px solid rgba(255, 255, 255, 0.18);
		color: rgba(255, 255, 255, 0.98);
	}

	.assistant-card {
		background: rgba(2, 6, 23, 0.8);
		border: 1px solid rgba(255, 255, 255, 0.18);
	}

	/* Scrollbar personalizada */
	:global(.overflow-y-auto::-webkit-scrollbar) {
		width: 8px;
	}
	
	:global(.overflow-y-auto::-webkit-scrollbar-track) {
		background: rgba(255, 255, 255, 0.05);
		border-radius: 4px;
	}
	
	:global(.overflow-y-auto::-webkit-scrollbar-thumb) {
		background: rgba(255, 255, 255, 0.2);
		border-radius: 4px;
	}
	
	:global(.overflow-y-auto::-webkit-scrollbar-thumb:hover) {
		background: rgba(255, 255, 255, 0.3);
	}
</style>
