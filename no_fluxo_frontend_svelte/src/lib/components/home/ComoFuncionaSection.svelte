<script lang="ts">
	import FeatureCard from './FeatureCard.svelte';
	import { ClipboardList, PlusCircle, CheckCircle } from 'lucide-svelte';

	const features = [
		{
			icon: ClipboardList,
			title: 'VISUALIZE SEU FLUXO',
			description:
				'Veja todas as disciplinas do seu curso organizadas por semestre e pré-requisitos.',
			gradientFrom: '#9333EA',
			gradientTo: '#EC4899'
		},
		{
			icon: PlusCircle,
			title: 'ADICIONE OPTATIVAS',
			description:
				'Personalize seu fluxograma adicionando matérias optativas de acordo com seus interesses.',
			gradientFrom: '#EC4899',
			gradientTo: '#F97316'
		},
		{
			icon: CheckCircle,
			title: 'ACOMPANHE SEU PROGRESSO',
			description:
				'Marque as disciplinas já cursadas e visualize seu progresso no curso de forma clara.',
			gradientFrom: '#F97316',
			gradientTo: '#EAB308'
		}
	];
</script>

<section class="como-funciona-section">
	<h2 class="section-title">COMO FUNCIONA</h2>

	<div class="feature-cards">
		{#each features as feature}
			<FeatureCard
				icon={feature.icon}
				title={feature.title}
				description={feature.description}
				gradientFrom={feature.gradientFrom}
				gradientTo={feature.gradientTo}
			/>
		{/each}
	</div>
</section>

<style>
	.section-title {
		font-family: 'Permanent Marker', cursive;
		color: white;
		font-size: clamp(1.5rem, 4vw, 2rem);
		text-align: center;
		letter-spacing: 1.5px;
		text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
		margin-bottom: 3rem;
	}

	.como-funciona-section {
		padding: 4rem 1.5rem;
		background: rgba(0, 0, 0, 0.5);
	}

	.feature-cards {
		display: grid;
		grid-template-columns: 1fr;
		gap: 2rem;
		max-width: 1200px;
		margin: 0 auto;
	}

	@media (min-width: 768px) {
		.feature-cards {
			grid-template-columns: repeat(3, 1fr);
		}
	}
</style>
