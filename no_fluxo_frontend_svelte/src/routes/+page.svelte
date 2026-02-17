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
	<meta property="og:title" content="NoFluxo UNB - Fluxograma Interativo para Estudantes" />
	<meta property="og:description" content="Visualize seu fluxograma, adicione optativas e acompanhe seu progresso acadêmico na UnB." />
	<meta property="og:type" content="website" />
	<meta property="og:locale" content="pt_BR" />
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
