<script lang="ts">
	import GraffitiBackground from '$lib/components/effects/GraffitiBackground.svelte';
	import Navbar from '$lib/components/layout/Navbar.svelte';
	import HeroSection from '$lib/components/home/HeroSection.svelte';
	import ComoFuncionaSection from '$lib/components/home/ComoFuncionaSection.svelte';
	import ProntoParaOrganizarSection from '$lib/components/home/ProntoParaOrganizarSection.svelte';
	import SobreNosSection from '$lib/components/home/SobreNosSection.svelte';
	import HomeFooter from '$lib/components/home/HomeFooter.svelte';
	import { currentUser, isAuthenticated } from '$lib/stores/auth';
</script>

<svelte:head>
	<title>NoFluxo UNB - Tenha Seu Fluxograma Muito Mais Fácil</title>
	<meta name="description" content="O NoFluxo UNB te ajuda a ver o fluxograma do seu curso e permite adicionar matérias optativas de acordo com suas áreas de interesse. Planejamento acadêmico inteligente para estudantes da UnB." />
	<meta name="keywords" content="UnB, fluxograma, planejamento acadêmico, FGA, disciplinas, grade curricular" />
	<link rel="canonical" href="https://nofluxo.unb.br/" />
	<meta property="og:site_name" content="NoFluxo UNB" />
	<meta property="og:title" content="NoFluxo UNB - Fluxograma Interativo para Estudantes" />
	<meta property="og:description" content="Visualize seu fluxograma, adicione optativas e acompanhe seu progresso acadêmico na UnB." />
	<meta property="og:type" content="website" />
	<meta property="og:url" content="https://nofluxo.unb.br/" />
	<meta property="og:image" content="https://nofluxo.unb.br/og-image.png" />
	<meta property="og:locale" content="pt_BR" />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:title" content="NoFluxo UNB - Fluxograma Interativo para Estudantes" />
	<meta name="twitter:description" content="Visualize seu fluxograma, adicione optativas e acompanhe seu progresso acadêmico na UnB." />
	<meta name="twitter:image" content="https://nofluxo.unb.br/og-image.png" />
	{@html `<script type="application/ld+json">${JSON.stringify({
		"@context": "https://schema.org",
		"@graph": [
			{
				"@type": "WebSite",
				"@id": "https://nofluxo.unb.br/#website",
				"url": "https://nofluxo.unb.br/",
				"name": "NoFluxo UNB",
				"description": "Planejamento acadêmico inteligente para estudantes da Universidade de Brasília",
				"inLanguage": "pt-BR",
				"potentialAction": {
					"@type": "SearchAction",
					"target": "https://nofluxo.unb.br/disciplinas?q={search_term_string}",
					"query-input": "required name=search_term_string"
				}
			},
			{
				"@type": "EducationalOrganization",
				"@id": "https://nofluxo.unb.br/#organization",
				"name": "NoFluxo UNB",
				"url": "https://nofluxo.unb.br/",
				"description": "Ferramenta de fluxogramas acadêmicos para estudantes da UnB",
				"parentOrganization": {
					"@type": "CollegeOrUniversity",
					"name": "Universidade de Brasília",
					"alternateName": "UnB",
					"url": "https://www.unb.br/"
				}
			}
		]
	})}</script>`}
</svelte:head>

<GraffitiBackground />

<!-- Navbar overlaid on top -->
<div class="fixed top-0 left-0 right-0 z-50">
	<Navbar user={$currentUser} isAuthenticated={$isAuthenticated} />
</div>

<main class="relative min-h-screen">
	<HeroSection />
	<ComoFuncionaSection />
	<ProntoParaOrganizarSection />
	<SobreNosSection />
	<HomeFooter />
</main>
