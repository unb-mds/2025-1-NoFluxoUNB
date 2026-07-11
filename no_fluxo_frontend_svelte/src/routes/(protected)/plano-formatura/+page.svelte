<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { authStore } from '$lib/stores/auth';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { planoFormaturaStore } from '$lib/stores/plano-formatura.store.svelte';
	import PlanoFormaturaView from '$lib/components/plano-formatura/PlanoFormaturaView.svelte';
	import OnboardingModal from '$lib/components/plano-formatura/OnboardingModal.svelte';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import { ROUTES } from '$lib/config/routes';
	import type { PreferenciasPlano } from '$lib/types/plano-formatura';

	onMount(async () => {
		const authState = authStore.getUser();

		// Redireciona para login se não autenticado
		if (!authState) {
			goto(ROUTES.LOGIN);
			return;
		}

		// Garante que dados do curso estão carregados (necessário para o Motor 2)
		if (!fluxogramaStore.state.courseData) {
			const curriculoCompleto = authState.dadosFluxograma?.matrizCurricular ?? null;
			if (curriculoCompleto) {
				await fluxogramaStore.loadCourseDataByCurriculoCompleto(curriculoCompleto);
			} else {
				// Sem dados de curso: redireciona para upload
				goto(ROUTES.UPLOAD_HISTORICO);
				return;
			}
		}

		// Carrega preferências e decide se mostra onboarding ou gera direto
		await planoFormaturaStore.loadPreferencias();

		if (!planoFormaturaStore.needsOnboarding) {
			await planoFormaturaStore.gerar();
		}
	});

	async function handleOnboardingConfirm(prefs: PreferenciasPlano) {
		await planoFormaturaStore.savePreferencias(prefs);
	}

	function handleOnboardingClose() {
		planoFormaturaStore.closeOnboarding();
		// Se nunca gerou um plano e o usuário fecha sem confirmar, tenta gerar com defaults
		if (planoFormaturaStore.status === 'idle') {
			planoFormaturaStore.gerar();
		}
	}
</script>

<PageMeta
	title="Plano de Formatura | NoFluxo UNB"
	description="Planejamento personalizado de matérias para sua formatura na UnB."
/>

<!-- Onboarding modal (first visit or ajustar preferências) -->
<OnboardingModal
	open={planoFormaturaStore.showOnboarding}
	onConfirm={handleOnboardingConfirm}
	onClose={handleOnboardingClose}
/>

<!-- Main view: ocupa a tela inteira disponível -->
<div class="flex h-full min-h-screen flex-col">
	<PlanoFormaturaView />
</div>
