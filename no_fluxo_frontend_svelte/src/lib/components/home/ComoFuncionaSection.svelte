<script lang="ts">
	import FeatureCard from './FeatureCard.svelte';
	import { scrollReveal } from '$lib/actions/scrollReveal';
	import {
		ClipboardList,
		PlusCircle,
		CheckCircle,
		Bot,
		ArrowRightLeft,
		GitCompare
	} from 'lucide-svelte';

	const features = [
		{
			icon: ClipboardList,
			title: 'Visualize sua grade',
			description:
				'Veja todas as disciplinas do seu curso organizadas por semestre, com os pré-requisitos visíveis num só lugar.'
		},
		{
			icon: PlusCircle,
			title: 'Planeje optativas',
			description:
				'Inclua optativas no seu fluxograma e visualize como elas se encaixam no seu percurso. Bom pra quem já sabe no que quer se aprofundar e pra quem ainda tá descobrindo.'
		},
		{
			icon: ArrowRightLeft,
			title: 'Simule mudança de curso',
			description:
				'Curioso pra saber como ficaria seu histórico em outro curso? Simule a integralização e veja o que aproveita.'
		},
		{
			icon: Bot,
			title: 'Assistente de IA',
			description:
				'Converse com a IA pra descobrir optativas alinhadas ao que te interessa e tirar dúvidas sobre matérias do seu curso.'
		},
		{
			icon: CheckCircle,
			title: 'Acompanhe o progresso',
			description:
				'Veja exatamente quanto falta pra formar, quais matérias você já cumpriu e quais ainda precisam entrar no seu plano.'
		},
		{
			icon: GitCompare,
			title: 'Encontre equivalências',
			description:
				'Descubra matérias equivalentes em outras matrizes e campi da UnB sem precisar caçar no SIGAA.'
		}
	];
</script>

<section class="como-section border-t border-white/[0.06]">
	<div class="section-header" use:scrollReveal={{ delay: 0 }}>
		<span class="nf-eyebrow">Funcionalidades</span>
		<h2 class="section-heading">Como funciona</h2>
		<p class="section-sub">
			Tudo que você precisa pra planejar sua jornada acadêmica em um só lugar.
		</p>
	</div>
	<div class="feature-cards">
		{#each features as feature, i}
			<FeatureCard icon={feature.icon} title={feature.title} description={feature.description} index={i} />
		{/each}
	</div>
</section>

<style>
	.como-section {
		padding: clamp(3.5rem, 8vw, 4.5rem) 1.5rem;
		background: hsl(var(--background) / 0.85);
	}

	.section-header {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.625rem;
		margin-bottom: 2.75rem;
	}

	.section-heading {
		font-size: clamp(1.375rem, 3vw, 1.75rem);
		font-weight: 800;
		letter-spacing: -0.03em;
		text-align: center;
		color: hsl(var(--foreground));
		margin: 0;
	}

	.section-sub {
		font-size: clamp(0.8125rem, 1.4vw, 0.9375rem);
		color: hsl(var(--muted-foreground));
		text-align: center;
		max-width: 480px;
		margin: 0;
		line-height: 1.6;
	}

	.feature-cards {
		display: grid;
		grid-template-columns: 1fr;
		gap: 1rem;
		max-width: 1120px;
		margin: 0 auto;
	}

	@media (min-width: 768px) {
		.feature-cards {
			grid-template-columns: repeat(3, minmax(0, 1fr));
			gap: 1.1rem;
		}
	}
</style>
