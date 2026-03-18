<script lang="ts">
	import Navbar from '$lib/components/layout/Navbar.svelte';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import { currentUser, isAuthenticated } from '$lib/stores/auth';
</script>

<PageMeta
	title="Política de Privacidade"
	description="Política de Privacidade do NoFluxo UNB — como coletamos, usamos e protegemos seus dados em conformidade com a LGPD."
/>

<div class="fixed top-0 left-0 right-0 z-50">
	<Navbar user={$currentUser} isAuthenticated={$isAuthenticated} />
</div>

<main class="min-h-screen pt-20 pb-12 bg-white">
	<div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
		<div class="prose prose-sm sm:prose lg:prose-lg max-w-none">
			<h1 class="text-3xl font-bold text-gray-900 mb-8">Política de Privacidade</h1>

			<p class="text-gray-700 leading-relaxed mb-8 text-lg">
				A sua privacidade é importante para nós. É política do NoFluxo UNB respeitar a sua privacidade em
				relação a qualquer informação sua que possamos coletar no site NoFluxo UNB e outros sites que
				possuímos e operamos.
			</p>

			<section class="mb-8">
				<h2 class="text-2xl font-semibold text-gray-800 mt-6 mb-4">1. Coleta de Informações</h2>
				<p class="text-gray-700 leading-relaxed">
                Solicitamos informações pessoais e acadêmicas (como o histórico escolar via PDF) apenas quando 
                necessário para fornecer o serviço de recomendação de disciplinas. O processamento desses dados
                ocorre localmente ou via APIs de inteligência artificial de forma segura, com o seu conhecimento 
                e consentimento.
				</p>
			</section>

			<section class="mb-8">
				<h2 class="text-2xl font-semibold text-gray-800 mt-6 mb-4">2. Uso e Retenção</h2>
				<p class="text-gray-700 leading-relaxed">
                Os dados coletados são retidos apenas pelo tempo necessário para a execução do serviço. Informações
                sensíveis extraídas de documentos acadêmicos são utilizadas exclusivamente para a análise do fluxo e
                não são compartilhadas com terceiros para fins comerciais. Empregamos medidas de segurança comercialmente
                aceitáveis para evitar perdas, roubos ou acessos não autorizados.
				</p>
			</section>

			<section class="mb-8">
				<h2 class="text-2xl font-semibold text-gray-800 mt-6 mb-4">3. Direitos do Usuário (LGPD)</h2>
				<p class="text-gray-700 leading-relaxed">
                Em conformidade com a Lei Geral de Proteção de Dados (LGPD), você tem o direito de acessar, corrigir ou 
                solicitar a exclusão de seus dados. Como o projeto é Open Source, nosso código-fonte está disponível 
                publicamente para auditoria, garantindo que o tratamento de dados seja transparente e auditável pela 
                comunidade da UnB.
				</p>
			</section>

			<section class="mb-8">
				<h2 class="text-2xl font-semibold text-gray-800 mt-6 mb-4">4. Cookies e Publicidade</h2>
				<p class="text-gray-700 leading-relaxed">
					O serviço Google AdSense usa um cookie DoubleClick para veicular anúncios mais relevantes e limitar
					a frequência de exibição.
				</p>
				<p class="text-gray-700 leading-relaxed mt-4">
					Utilizamos anúncios para compensar os custos de infraestrutura e desenvolvimento do projeto.
				</p>
				<p class="text-gray-700 leading-relaxed mt-4">
					Você é livre para recusar a nossa solicitação de informações ou cookies, entendendo que talvez não
					possamos fornecer alguns dos serviços desejados.
				</p>
			</section>
		</div>
	</div>
</main>

<style global>
	.prose {
		color: #374151;
	}

	.prose h2 {
		color: #1f2937;
	}

	.prose p {
		margin-bottom: 1rem;
		line-height: 1.6;
	}

	.prose strong {
		font-weight: 600;
		color: #1f2937;
	}
</style>
