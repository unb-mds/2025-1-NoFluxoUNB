<script lang="ts">
	import { Check } from 'lucide-svelte';
	import MemberCard from './MemberCard.svelte';

	const teamMembers = [
		{
			name: 'Guilherme Gusmão',
			githubUsername: 'gusmoles',
			specialties: ['Frontend', 'UX/UI', 'Design'],
			linkedin: 'https://www.linkedin.com/in/guilherme-gusmão-nepomuceno-9b44a826a/',
			email: ''
		},
		{
			name: 'Vitor Marconi',
			githubUsername: 'Vitor-Trancoso',
			specialties: ['Fullstack', 'Design', 'Arquitetura visual'],
			linkedin: 'https://www.linkedin.com/in/vitor-marconi-4a069524a/',
			email: ''
		},
		{
			name: 'Gustavo Choueiri',
			githubUsername: 'staann',
			specialties: ['Inteligência Artificial', 'Automações', 'Engenharia de Dados'],
			linkedin: 'https://www.linkedin.com/in/gustavochoueiri',
			email: ''
		},
		{
			name: 'Felipe Pedroza',
			githubUsername: 'darkymeubem',
			specialties: ['Banco de dados', 'Ciência de dados', 'Fullstack'],
			linkedin: 'https://www.linkedin.com/in/felipe-lopes-pedroza-74b7a527b/',
			email: ''
		},
		{
			name: 'Vinícius Pereira',
			githubUsername: 'Vinicius-Ribeiro04',
			specialties: ['Frontend', 'Design', 'Canvas'],
			linkedin: 'https://www.linkedin.com/in/vinicius-ribeiro-6192b2270/',
			email: ''
		},
		{
			name: 'Arthur Fernandes',
			githubUsername: 'hisarxt',
			specialties: ['QA Analyst', 'Banco de dados', 'Frontend'],
			linkedin: 'https://www.linkedin.com/in/artxrz/',
			email: ''
		},
		{
			name: 'Erick Alves',
			githubUsername: 'erickaalves',
			specialties: ['Frontend', 'Scrum', 'Trafego pago'],
			linkedin: '',
			email: ''
		},
		{
			name: 'Arthur Ramalho',
			githubUsername: 'ArthurNRamalho',
			specialties: ['Design', 'Documentação', 'Planejamento'],
			linkedin: '',
			email: ''
		},
		{
			name: 'Otavio Maya',
			githubUsername: 'knz13',
			specialties: ['Fullstack', 'Integração', 'Dockerização'],
			linkedin: 'https://www.linkedin.com/in/otávio-maya-8416931a5/',
			email: ''
		}
	];

	const features = [
		{
			title: 'UX moderna:',
			linkedin: '',
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
	>
		<p class="sobre-text">
			O NoFluxoUnB é criado na disciplina de Métodos de Desenvolvimento de Software ministrada pela
			professora Carla Rocha, com a proposta de desenvolver um software inovador para a comunidade.
			Nossa proposta foi desenvolver um software que facilita o planejamento acadêmico dos
			estudantes da UnB, oferecendo um fluxograma interativo, intuitivo e de fácil uso. Visualize
			matérias equivalentes, selecione disciplinas futuras e receba recomendações personalizadas com
			inteligência artificial.
		</p>

		<!--
		<div class="sobre-note">
			<MessageCircle class="h-4 w-4 shrink-0 text-white/70" />
			<p>
				<strong>Observação:</strong> Inicialmente disponível para cursos da FGA/UnB, com perspectiva
				de expansão!
			</p>
		</div>
		-->
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
			<MemberCard
				name={member.name}
				githubUsername={member.githubUsername}
				specialties={member.specialties}
				//instagram={member.instagram}
				linkedin={member.linkedin}
				email={member.email}
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

	.sobre-card:hover {
		transform: scale(1.02);
	}

	.sobre-text {
		color: white;
		font-size: clamp(0.8125rem, 1.5vw, 1.125rem);
		line-height: 1.7;
		text-align: justify;
		margin-bottom: 0.75rem;
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
