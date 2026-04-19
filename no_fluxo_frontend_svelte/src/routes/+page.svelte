<script lang="ts">
	import GraffitiBackground from '$lib/components/effects/GraffitiBackground.svelte';
	import Navbar from '$lib/components/layout/Navbar.svelte';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import JsonLd from '$lib/components/seo/JsonLd.svelte';
	import HeroSection from '$lib/components/home/HeroSection.svelte';
	import ComoFuncionaSection from '$lib/components/home/ComoFuncionaSection.svelte';
	import ProntoParaOrganizarSection from '$lib/components/home/ProntoParaOrganizarSection.svelte';
	import SobreNosSection from '$lib/components/home/SobreNosSection.svelte';
	import HomeFooter from '$lib/components/home/HomeFooter.svelte';
	import { currentUser, isAuthenticated } from '$lib/stores/auth';

	const websiteJsonLd = {
		'@context': 'https://schema.org',
		'@type': 'WebSite',
		name: 'NoFluxo UNB',
		alternateName: ['No Fluxo UNB', 'NoFluxoUnB'],
		url: 'https://nofluxo.unb.br'
	};

	const organizationJsonLd = {
		'@context': 'https://schema.org',
		'@type': 'Organization',
		name: 'NoFluxo UNB',
		alternateName: ['No Fluxo UNB', 'NoFluxoUnB'],
		url: 'https://nofluxo.unb.br',
		logo: 'https://nofluxo.unb.br/og-image.png'
	};
</script>

<PageMeta
	title="No Fluxo UNB: fluxograma acadêmico inteligente"
	description="No Fluxo UNB (NoFluxo) te ajuda a visualizar fluxogramas, planejar disciplinas e acompanhar seu progresso acadêmico na UnB."
/>
<JsonLd data={websiteJsonLd} />
<JsonLd data={organizationJsonLd} />

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
