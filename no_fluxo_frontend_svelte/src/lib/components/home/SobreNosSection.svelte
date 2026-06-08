<script lang="ts">
	import { Check } from 'lucide-svelte';
	import { onMount } from 'svelte';
	import MemberCard from './MemberCard.svelte';
	import { scrollReveal } from '$lib/actions/scrollReveal';

	type Tab = 'todos' | 'atuais' | 'contribuintes';
	let activeTab = $state<Tab>('atuais');

	const TAB_ORDER: Tab[] = ['atuais', 'contribuintes', 'todos'];
	const AUTO_INTERVAL = 5000;
	let paused = $state(false);
	let pauseTimer: ReturnType<typeof setTimeout>;

	function selectTab(tab: Tab) {
		activeTab = tab;
		paused = true;
		clearTimeout(pauseTimer);
		pauseTimer = setTimeout(() => (paused = false), 12000);
	}

	onMount(() => {
		const id = setInterval(() => {
			if (paused) return;
			const idx = TAB_ORDER.indexOf(activeTab);
			activeTab = TAB_ORDER[(idx + 1) % TAB_ORDER.length]!;
		}, AUTO_INTERVAL);
		return () => {
			clearInterval(id);
			clearTimeout(pauseTimer);
		};
	});

	interface Member {
		name: string;
		githubUsername: string;
		specialties: string[];
		linkedin: string;
		email: string;
		role?: string;
	}

	const allDevs: Member[] = [
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

	const activeDevs: Member[] = allDevs.filter((m) =>
		['Vitor-Trancoso', 'darkymeubem', 'knz13', 'staann'].includes(m.githubUsername)
	);

	const contributors: Member[] = [
		{
			name: 'Vitor Marconi T. Albuquerque',
			githubUsername: 'Vitor-Trancoso',
			specialties: ['Testes de Software', 'QA', 'Automação'],
			linkedin: 'https://www.linkedin.com/in/vitor-marconi-4a069524a/',
			email: '',
			role: 'Contribuinte'
		},
		{
			name: 'Vinícius de Jesus B. Fernandes',
			githubUsername: 'ViniJBessa',
			specialties: ['Testes de Software', 'QA'],
			linkedin: '',
			email: '',
			role: 'Contribuinte'
		},
		{
			name: 'André Henrique S. Belarmino',
			githubUsername: 'andrehbelarmino',
			specialties: ['Testes de Software', 'QA'],
			linkedin: '',
			email: '',
			role: 'Contribuinte'
		},
		{
			name: 'Kauan Felipe Lima Sousa',
			githubUsername: 'KauanFLS',
			specialties: ['Testes de Software', 'QA'],
			linkedin: '',
			email: '',
			role: 'Contribuinte'
		},
		{
			name: 'Enzo Lopes Ferreira',
			githubUsername: 'lopes061',
			specialties: ['Testes de Software', 'QA', 'Frontend'],
			linkedin: '',
			email: '',
			role: 'Contribuinte'
		}
	];

	const visibleMembers = $derived(
		activeTab === 'todos' ? allDevs : activeTab === 'atuais' ? activeDevs : contributors
	);

	const tabs: { id: Tab; label: string; count: number }[] = [
		{ id: 'todos', label: 'Desenvolvedores', count: allDevs.length },
		{ id: 'atuais', label: 'Atuais', count: activeDevs.length },
		{ id: 'contribuintes', label: 'Contribuintes', count: contributors.length }
	];

	const features = [
		{ description: 'Feito por estudantes, pra estudantes da UnB.' },
		{ description: 'Pensado pra quem tem vida além da faculdade.' },
		{ description: 'Gratuito e construído com a comunidade em mente.' }
	];
</script>

<section class="sobre-section" id="sobre-nos">
	<!-- Header -->
	<div class="section-header" use:scrollReveal={{ delay: 0 }}>
		<span class="nf-eyebrow">Equipe</span>
		<h2 class="section-title">Sobre nós</h2>
	</div>

	<!-- Description card -->
	<div class="sobre-card nf-card-surface" use:scrollReveal={{ delay: 60 }}>
		<div class="sobre-body">
			<p class="sobre-lead">Tudo começou com um fluxograma impresso e uma caneta marca-texto.</p>

			<p class="sobre-text">
				Se você já chegou no fim do semestre tentando entender quais matérias liberar pro próximo,
				imprimindo o fluxograma de novo, riscando o que já passou, fazendo conta de cabeça pra
				projetar quando vai formar, você já sabe do que a gente tá falando.
			</p>

			<p class="sobre-text">
				O No Fluxo nasceu dessa dor. A vida do universitário não cabe num fluxograma "ideal": tem
				estágio, tem trabalho, tem projetos próprios, tem o semestre que não fechou o horário, a
				matéria equivalente que existe mas ninguém te contou.
			</p>

			<p class="sobre-text">
				O No Fluxo é um projeto da disciplina de Métodos de Desenvolvimento de Software, ministrada
				pela professora Dr. Carla Rocha na FCTE/UnB. A ideia era construir um software que
				resolvesse um problema real da comunidade.
			</p>
		</div>

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

	<!-- Team tabs -->
	<div class="team-section" use:scrollReveal={{ delay: 100 }}>
		<div class="tabs-bar" role="tablist" aria-label="Categorias da equipe">
			{#each tabs as tab}
				<button
					role="tab"
					aria-selected={activeTab === tab.id}
					class="tab-btn"
					class:tab-active={activeTab === tab.id}
					onclick={() => selectTab(tab.id)}
				>
					{tab.label}
					<span class="tab-count">{tab.count}</span>
					{#if activeTab === tab.id && !paused}
						{#key activeTab}
							<span class="tab-progress" aria-hidden="true"></span>
						{/key}
					{/if}
				</button>
			{/each}
		</div>

		{#if activeTab === 'atuais'}
			<p class="tab-description">
				Equipe principal ativa no desenvolvimento atual do produto.
			</p>
		{:else if activeTab === 'contribuintes'}
			<p class="tab-description">
				Equipe 2 de Testes de Software — responsável pela qualidade e cobertura de testes.
			</p>
		{/if}

		{#key activeTab}
			<div
				class="team-grid"
				class:team-grid--compact={activeTab === 'contribuintes' || activeTab === 'atuais'}
			>
				{#each visibleMembers as member, i}
					<div class="card-anim" style="--i: {i}">
						<MemberCard
							name={member.name}
							githubUsername={member.githubUsername}
							specialties={member.specialties}
							linkedin={member.linkedin}
							email={member.email}
							role={member.role ?? 'Desenvolvedor'}
						/>
					</div>
				{/each}
			</div>
		{/key}
	</div>
</section>

<style>
	.sobre-section {
		padding: clamp(3.5rem, 8vw, 4.5rem) 1.5rem;
		background: hsl(var(--background) / 0.9);
		border-top: 1px solid hsl(0 0% 100% / 0.06);
	}

	.section-header {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.625rem;
		margin-bottom: 2.75rem;
	}

	.section-title {
		font-size: clamp(1.375rem, 3vw, 1.75rem);
		font-weight: 800;
		letter-spacing: -0.03em;
		text-align: center;
		color: hsl(var(--foreground));
		margin: 0;
	}

	/* Description card */
	.sobre-card {
		max-width: 1120px;
		margin: 0 auto 2.5rem;
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
	}

	.sobre-text {
		color: hsl(var(--muted-foreground));
		font-size: clamp(0.8125rem, 1.5vw, 1.0625rem);
		line-height: 1.7;
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
	}

	/* Team section */
	.team-section {
		max-width: 1120px;
		margin: 0 auto;
	}

	/* Tabs bar */
	.tabs-bar {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		background: hsl(var(--card) / 0.7);
		border: 1px solid hsl(var(--border) / 0.7);
		border-radius: 12px;
		padding: 0.3rem;
		width: fit-content;
		margin: 0 auto 1.5rem;
	}

	.tab-btn {
		position: relative;
		overflow: hidden;
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		border-radius: 8px;
		border: none;
		background: transparent;
		color: hsl(var(--muted-foreground));
		font-size: 0.8125rem;
		font-weight: 600;
		letter-spacing: 0.01em;
		cursor: pointer;
		transition:
			background 0.18s ease,
			color 0.18s ease,
			box-shadow 0.18s ease;
		white-space: nowrap;
	}

	.tab-btn:hover:not(.tab-active) {
		background: hsl(var(--primary) / 0.08);
		color: hsl(var(--foreground));
	}

	.tab-active {
		background: hsl(var(--primary));
		color: hsl(var(--primary-foreground));
		box-shadow:
			0 0 0 1px hsl(var(--primary) / 0.4),
			0 0 14px hsl(var(--primary) / 0.3);
	}

	.tab-progress {
		position: absolute;
		bottom: 0;
		left: 0;
		height: 2px;
		width: 0%;
		border-radius: 999px;
		background: hsl(0 0% 100% / 0.6);
		animation: tab-fill 5s linear forwards;
	}

	@keyframes tab-fill {
		from { width: 0%; }
		to { width: 100%; }
	}

	.tab-count {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-width: 20px;
		height: 18px;
		padding: 0 0.3rem;
		border-radius: 999px;
		font-size: 0.6875rem;
		font-weight: 700;
		background: hsl(0 0% 100% / 0.15);
	}

	.tab-active .tab-count {
		background: hsl(0 0% 100% / 0.25);
	}

	.tab-description {
		text-align: center;
		font-size: 0.8125rem;
		color: hsl(var(--muted-foreground));
		margin: 0 0 1.5rem;
		line-height: 1.5;
	}

	/* Team grid */
	.team-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
	}

	.team-grid--compact {
		max-width: 820px;
		margin: 0 auto;
	}

	@media (min-width: 640px) {
		.team-grid--compact {
			grid-template-columns: repeat(3, 1fr);
		}
	}

	@media (min-width: 768px) {
		.team-grid {
			grid-template-columns: repeat(4, 1fr);
			gap: 1.25rem;
		}
		.team-grid--compact {
			grid-template-columns: repeat(3, 1fr);
		}
	}

	@media (min-width: 1024px) {
		.team-grid--compact {
			grid-template-columns: repeat(5, 1fr);
		}
	}

	/* Card entrance animation on tab switch */
	.card-anim {
		animation: card-enter 0.3s cubic-bezier(0.16, 1, 0.3, 1) calc(var(--i) * 45ms) both;
	}

	@keyframes card-enter {
		from {
			opacity: 0;
			transform: translateY(14px) scale(0.97);
		}
		to {
			opacity: 1;
			transform: none;
		}
	}
</style>
