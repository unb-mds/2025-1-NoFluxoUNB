<script lang="ts">
	import { Check, MessageCircle } from 'lucide-svelte';
	import MemberCard from './MemberCard.svelte';

	let isCardHovered = $state(false);

	const teamMembers = [
		{ name: 'Guilherme Gusmão', githubUsername: 'gusmoles' },
		{ name: 'Vitor Marconi', githubUsername: 'Vitor-Trancoso' },
		{ name: 'Gustavo Choueiri', githubUsername: 'staann' },
		{ name: 'Felipe Lopes', githubUsername: 'darkymeubem' },
		{ name: 'Vinícius Pereira', githubUsername: 'Vinicius-Ribeiro04' },
		{ name: 'Arthur Fernandes', githubUsername: 'hisarxt' },
		{ name: 'Erick Alves', githubUsername: 'erickaalves' },
		{ name: 'Arthur Ramalho', githubUsername: 'ArthurNRamalho' }
	];

	const features = [
		{
			title: 'UX moderna:',
			description: 'Interface visual clara, responsiva e fácil de navegar.'
		},
		{
			title: 'Inteligência Artificial:',
			description: 'Sugestão de disciplinas alinhadas aos interesses do estudante.'
		},
		{
			title: 'Personalização:',
			description:
				'Planejamento acadêmico inteligente e eficiente, adaptado ao perfil do aluno.'
		}
	];
</script>

<section class="sobre-section" id="sobre-nos">
	<h2 class="section-title">SOBRE NÓS</h2>

	<div
		class="sobre-card"
		onmouseenter={() => (isCardHovered = true)}
		onmouseleave={() => (isCardHovered = false)}
		style="transform: scale({isCardHovered ? 1.02 : 1});"
	>
		<p class="sobre-text">
			O NoFluxoUnB é criado na disciplina de Métodos de Desenvolvimento de Software ministrada pela
			professora Carla Rocha, com a proposta de desenvolver um software inovador para a comunidade.
			Nossa proposta foi desenvolver um software que facilita o planejamento acadêmico dos
			estudantes da UnB, oferecendo um fluxograma interativo, intuitivo e de fácil uso. Visualize
			matérias equivalentes, selecione disciplinas futuras e receba recomendações personalizadas com
			inteligência artificial.
		</p>

		<div class="sobre-note">
			<MessageCircle class="h-4 w-4 shrink-0 text-white/70" />
			<p>
				<strong>Observação:</strong> Inicialmente disponível para cursos da FGA/UnB, com perspectiva
				de expansão!
			</p>
		</div>

		<div class="sobre-features">
			{#each features as feature}
				<div class="sobre-feature">
					<span class="check-circle">
						<Check class="h-4 w-4 text-white" />
					</span>
					<p><strong>{feature.title}</strong> {feature.description}</p>
				</div>
			{/each}
		</div>
	</div>

	<div class="team-grid">
		{#each teamMembers as member}
			<MemberCard name={member.name} githubUsername={member.githubUsername} />
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

	.sobre-section {
		padding: 4rem 1.5rem;
		background: rgba(0, 0, 0, 0.5);
	}

	.sobre-card {
		max-width: 1200px;
		margin: 0 auto 2rem;
		padding: 2rem;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 24px;
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
		transition: transform 0.2s ease;
	}

	.sobre-text {
		color: white;
		font-size: clamp(0.8125rem, 1.5vw, 1.125rem);
		line-height: 1.7;
		text-align: justify;
		margin-bottom: 0.75rem;
	}

	.sobre-note {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		margin-bottom: 1.125rem;
	}

	.sobre-note p {
		color: rgba(255, 255, 255, 0.8);
		font-size: clamp(0.6875rem, 1.2vw, 0.875rem);
		font-style: italic;
	}

	.sobre-features {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.sobre-feature {
		display: flex;
		align-items: center;
		gap: 0.625rem;
	}

	.sobre-feature p {
		color: white;
		font-size: clamp(0.6875rem, 1.2vw, 0.9375rem);
	}

	.check-circle {
		width: 28px;
		height: 28px;
		min-width: 28px;
		border-radius: 50%;
		background: linear-gradient(to right, #ec4899, #8b5cf6);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.team-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
		max-width: 1200px;
		margin: 0 auto;
	}

	@media (min-width: 768px) {
		.team-grid {
			grid-template-columns: repeat(4, 1fr);
			gap: 1.5rem;
		}
	}
</style>
