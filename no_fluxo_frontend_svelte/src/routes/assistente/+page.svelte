<script lang="ts">
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import { Bot, Send, Loader2, Sparkles } from 'lucide-svelte';
	import { AssistenteService } from '$lib/services/assistente.service';
	
	let mensagem = '';
	let carregando = false;
	let historico: Array<{ tipo: 'usuario' | 'assistente', texto: string, disciplinas?: any[] }> = [];
	
	const assistente = new AssistenteService();
	
	async function enviarMensagem() {
		if (!mensagem.trim() || carregando) return;
		
		const mensagemUsuario = mensagem.trim();
		mensagem = '';
		
		// Adiciona mensagem do usuário ao histórico
		historico = [...historico, { tipo: 'usuario', texto: mensagemUsuario }];
		
		carregando = true;
		
		try {
			const resposta = await assistente.sendMessageToSabia(mensagemUsuario);
			
			// Backend retorna: { resultado, disciplinas, agente } ou { erro }
			if (resposta.erro) {
				historico = [...historico, { 
					tipo: 'assistente', 
					texto: `❌ Erro: ${resposta.erro}` 
				}];
			} else {
				historico = [...historico, { 
					tipo: 'assistente', 
					texto: resposta.resultado || 'Resposta recebida', 
					disciplinas: resposta.disciplinas 
				}];
			}
		} catch (erro: any) {
			historico = [...historico, { 
				tipo: 'assistente', 
				texto: `❌ Erro ao conectar: ${erro.message}` 
			}];
		} finally {
			carregando = false;
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

<div class="relative z-10 container mx-auto max-w-5xl px-4 py-8 h-[calc(100vh-100px)] flex flex-col">
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

	<!-- Chat Container -->
	<div class="flex-1 glass-light rounded-2xl overflow-hidden flex flex-col">
		<!-- Mensagens -->
		<div class="flex-1 overflow-y-auto p-6 space-y-4">
			{#if historico.length === 0}
				<div class="h-full flex flex-col items-center justify-center text-center">
					<Bot class="h-16 w-16 text-pink-400 mb-4 opacity-50" />
					<h2 class="text-xl font-semibold text-white mb-2">Como posso ajudar?</h2>
					<p class="text-gray-400 max-w-md">
						Pergunte sobre áreas de estudos de interesse e retornarei recomendações de disciplinas da UnB!
					</p>
				<div class="mt-6 grid grid-cols-1 sm:grid-cols-2 gap-3 max-w-2xl">
					<button
						on:click={() => { mensagem = 'Direito Constitucional e Teoria da Constituição'; enviarMensagem(); }}
						class="glass-light p-3 rounded-lg hover:bg-white/10 transition-colors text-left"
					>
						<p class="text-white text-sm">⚖️ Direito Constitucional</p>
					</button>

					<button
						on:click={() => { mensagem = 'História da África: Sociedades Pré-Coloniais e Processos de Independência'; enviarMensagem(); }}
						class="glass-light p-3 rounded-lg hover:bg-white/10 transition-colors text-left"
					>
						<p class="text-white text-sm">🌍 História da África</p>
					</button>

					<button
						on:click={() => { mensagem = 'Inteligência Artificial: Aprendizado de Máquina e Redes Neurais'; enviarMensagem(); }}
						class="glass-light p-3 rounded-lg hover:bg-white/10 transition-colors text-left"
					>
						<p class="text-white text-sm">🤖 Inteligência Artificial</p>
					</button>

					<button
						on:click={() => { mensagem = 'Bioética e Saúde Coletiva no Sistema Único de Saúde'; enviarMensagem(); }}
						class="glass-light p-3 rounded-lg hover:bg-white/10 transition-colors text-left"
					>
						<p class="text-white text-sm">🦠 Microbiologia</p>
					</button>

					<button
						on:click={() => { mensagem = 'Macroeconomia: Modelos de Crescimento e Políticas Monetárias'; enviarMensagem(); }}
						class="glass-light p-3 rounded-lg hover:bg-white/10 transition-colors text-left"
					>
						<p class="text-white text-sm">📈 Macroeconomia</p>
					</button>

					<button
						on:click={() => { mensagem = 'Cálculo Diferencial e Integral para Engenharia'; enviarMensagem(); }}
						class="glass-light p-3 rounded-lg hover:bg-white/10 transition-colors text-left"
					>
						<p class="text-white text-sm">⚛️ Física Quântica</p>
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
								<div class="glass-light rounded-2xl px-4 py-3">
									<!-- Só mostra o texto se NÃO houver disciplinas -->
									{#if !msg.disciplinas || msg.disciplinas.length === 0}
										<p class="text-white whitespace-pre-wrap">{msg.texto}</p>
									{/if}
									
									{#if msg.disciplinas && msg.disciplinas.length > 0}
										<!-- Título apenas para disciplinas -->
										<p class="text-white font-semibold mb-3">
											🎓 {msg.disciplinas.length} disciplinas encontradas
										</p>
										<div class="mt-4 space-y-2">
											{#each msg.disciplinas as disc}
												<div class="glass-light rounded-lg p-3 border border-white/10">
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
					<div class="glass-light rounded-2xl px-4 py-3">
						<div class="flex items-center gap-2 text-gray-400">
							<Loader2 class="h-4 w-4 animate-spin" />
							<span>Pensando...</span>
						</div>
					</div>
				</div>
			{/if}
		</div>

		<!-- Input -->
		<div class="border-t border-white/10 p-4">
			<form on:submit|preventDefault={enviarMensagem} class="flex gap-2">
				<input
					type="text"
					bind:value={mensagem}
					on:keypress={handleKeyPress}
					placeholder="Digite seu interesse (ex: machine learning)..."
					disabled={carregando}
					class="flex-1 bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-pink-500/50 disabled:opacity-50"
				/>
				<button
					type="submit"
					disabled={!mensagem.trim() || carregando}
					class="bg-gradient-to-br from-pink-500 to-purple-600 text-white rounded-xl px-6 py-3 font-medium hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
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
