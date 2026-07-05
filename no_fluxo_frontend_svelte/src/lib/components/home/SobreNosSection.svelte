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
		{ description: 'Feito por estudantes, pra estudantes da UnB.' },
		{ description: 'Pensado pra quem tem vida além da faculdade.' },
		{ description: 'Gratuito e construído com a comunidade em mente.' }
	];
</script>

<section class="sobre-section" id="sobre-nos">
	<h2 class="section-title">Sobre nós</h2>

	<div class="sobre-card nf-card-surface">
		<div class="sobre-body">
			<p class="sobre-lead">
				Tudo começou com um fluxograma impresso e uma caneta marca-texto.
			</p>

			<p class="sobre-text">
				Se você já chegou no fim do semestre tentando entender quais matérias liberar pro próximo,
				imprimindo o fluxograma de novo, riscando o que já passou, fazendo conta de cabeça pra
				projetar quando vai formar, você já sabe do que a gente tá falando.
			</p>

			<p class="sobre-text">
				O No Fluxo nasceu dessa dor. A vida do universitário não cabe num fluxograma "ideal": tem
				estágio, tem trabalho, tem projetos próprios, tem o semestre que não fechou o horário, a
				matéria equivalente que existe mas ninguém te contou. A UnB tem um monte de regra que o
				SIGAA não explica, e no fim quem se vira pra organizar tudo isso é você, geralmente
				sozinho, no Excel ou no papel.
			</p>

			<p class="sobre-text">
				Aí a gente fez uma pesquisa e percebeu que não era só com a gente. A maioria dos cursos da
				UnB nem tem um fluxograma visual decente, e os que têm ainda obrigam o aluno a grifar à mão
				toda vez que vai se matricular. Deu pra ver que dava pra fazer melhor.
			</p>

			<p class="sobre-text">
				O No Fluxo é um projeto da disciplina de Métodos de Desenvolvimento de Software, ministrada
				pela professora Dr Carla Rocha na FCTE/UnB. A ideia era construir um software que resolvesse um
				problema real da comunidade, e a gente escolheu resolver um que vivia toda semana.
			</p>
		</div>

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
						<Check class="h-4 w-4 text-primary-foreground" />
					</span>
					<p>{feature.description}</p>
				</div>
			{/each}
		</div>
	</div>

	<div class="team-grid">
		{#each teamMembers as member}
			<!-- TODO: add instagram={member.instagram} prop -->
			<MemberCard
				name={member.name}
				githubUsername={member.githubUsername}
				specialties={member.specialties}
				linkedin={member.linkedin}
				email={member.email}
			/>
		{/each}
	</div>
</section>

<style>
	.section-title {
		font-size: clamp(1.375rem, 3vw, 1.75rem);
		font-weight: 800;
		letter-spacing: -0.03em;
		text-align: center;
		color: hsl(var(--foreground));
		margin-bottom: 2.75rem;
	}

	.sobre-section {
		padding: clamp(3.5rem, 8vw, 4.5rem) 1.5rem;
		background: hsl(var(--background) / 0.9);
		border-top: 1px solid hsl(0 0% 100% / 0.06);
	}

	.sobre-card {
		max-width: 1120px;
		margin: 0 auto 2rem;
		padding: 2rem;
	}

	.sobre-body {
		display: flex;
		flex-direction: column;
		gap: 1.25rem;
		margin-bottom: 1.75rem;
	}

	.sobre-lead {
		color: hsl(var(--foreground));
		font-size: clamp(1.0625rem, 2.2vw, 1.375rem);
		font-weight: 700;
		line-height: 1.4;
		letter-spacing: -0.01em;
		text-align: left;
	}

	.sobre-text {
		color: hsl(var(--muted-foreground));
		font-size: clamp(0.8125rem, 1.5vw, 1.0625rem);
		line-height: 1.7;
		text-align: left;
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
		color: hsl(var(--foreground));
		font-size: clamp(0.75rem, 1.15vw, 0.9375rem);
		line-height: 1.45;
	}

	.check-circle {
		width: 28px;
		height: 28px;
		min-width: 28px;
		border-radius: 8px;
		background: hsl(var(--primary));
		display: flex;
		align-items: center;
		justify-content: center;
		margin-top: 2px;
	}

	.team-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
		max-width: 1120px;
		margin: 0 auto;
	}

	@media (min-width: 768px) {
		.team-grid {
			grid-template-columns: repeat(4, 1fr);
			gap: 1.5rem;
		}
	}
</style>
