<script lang="ts">
	import FeatureCard from './FeatureCard.svelte';
	import { ClipboardList, PlusCircle, CheckCircle, Bot, ArrowRightLeft } from 'lucide-svelte';

	const features = [
		{
			icon: ClipboardList,
			title: 'Visualize sua grade',
			description:
				'Disciplinas por semestre e pré-requisitos no mesmo painel, com leitura rápida e hierarquia clara.'
		},
		{
			icon: PlusCircle,
			title: 'Planeje optativas',
			description:
				'Inclua optativas no fluxo e alinhe seu percurso aos seus interesses mantendo o mesmo visual do produto.'
		},
		{
			icon: ArrowRightLeft,
			title: 'Simule mudança de curso',
			description:
				'Use seu histórico para explorar como ficaria a integralização em outro curso da UnB.'
		},
		{
			icon: Bot,
			title: 'Assistente de IA',
			description:
				'Converse com o assistente no mesmo sistema visual: lilás de apoio e componentes padronizados.'
		},
		{
			icon: CheckCircle,
			title: 'Acompanhe o progresso',
			description:
				'Status semânticos, carga horária e o que falta para concluir — com cards e legendas consistentes.'
		}
	];
</script>

<section class="como-section border-t border-white/[0.06]">
	<h2 class="section-heading">Como funciona</h2>
	<div class="feature-cards">
		{#each features as feature}
			<FeatureCard icon={feature.icon} title={feature.title} description={feature.description} />
		{/each}
	</div>
</section>

<style>
	.como-section {
		padding: clamp(3.5rem, 8vw, 4.5rem) 1.5rem;
		background: hsl(var(--background) / 0.85);
	}

	.section-heading {
		font-size: clamp(1.375rem, 3vw, 1.75rem);
		font-weight: 800;
		letter-spacing: -0.03em;
		text-align: center;
		color: hsl(var(--foreground));
		margin: 0 0 2.75rem;
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

		:global(.feature-cards .feature-card:nth-child(4)) {
			grid-column: 1;
			grid-row: 2;
		}

		:global(.feature-cards .feature-card:nth-child(5)) {
			grid-column: 3;
			grid-row: 2;
		}
	}
</style>
