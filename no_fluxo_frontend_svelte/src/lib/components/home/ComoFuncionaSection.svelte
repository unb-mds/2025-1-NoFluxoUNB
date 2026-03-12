<script lang="ts">
	import FeatureCard from './FeatureCard.svelte';
	import { ClipboardList, PlusCircle, CheckCircle, Bot, ArrowRightLeft } from 'lucide-svelte';

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
				'Personalize seu fluxograma adicionando matérias optativas alinhadas às suas áreas de interesse.',
			gradientFrom: '#EC4899',
			gradientTo: '#F97316'
		},
		{
			icon: ArrowRightLeft,
			title: 'SIMULE MUDANÇA DE CURSO',
			description:
				'Use seu histórico atual para ver como ficaria sua integralização em outro curso da UnB.',
			gradientFrom: '#F97316',
			gradientTo: '#22c55e'
		},
		{
			icon: Bot,
			title: 'ASSISTENTE DE IA',
			description:
				'Converse com a IA para receber sugestões de disciplinas e optativas que combinem com seus interesses.',
			gradientFrom: '#22c55e',
			gradientTo: '#EAB308'
		},
		{
			icon: CheckCircle,
			title: 'ACOMPANHE SEU PROGRESSO',
			description:
				'Marque as disciplinas já cursadas, veja carga horária integralizada e quanto falta para se formar.',
			gradientFrom: '#EAB308',
			gradientTo: '#6366F1'
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
			grid-template-columns: repeat(3, minmax(0, 1fr));
			grid-auto-rows: auto;
		}

		/* Colocando um "vácuo" na linha 2 coluna 2 e movendo os cards 4 e 5 */
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
