<script lang="ts">
	import { ChevronLeft, ChevronRight, Github, Instagram, Linkedin, Mail } from 'lucide-svelte';

	interface Props {
		name: string;
		githubUsername: string;
		specialties?: string[];
		instagram?: string;
		linkedin?: string;
		email?: string;
	}

	let {
		name,
		githubUsername,
		specialties = [],
		instagram = '',
		linkedin = '',
		email = ''
	}: Props = $props();
	let imageError = $state(false);
	let currentSlide = $state(0);

	const totalSlides = 3;

	const avatarUrl = $derived(`https://avatars.githubusercontent.com/${githubUsername}`);
	const githubUrl = $derived(`https://github.com/${githubUsername}`);
	const linkedinValue = $derived(linkedin.trim());
	const linkedinHandle = $derived(linkedinValue.replace('@', ''));
	const linkedinUrl = $derived(
		linkedinValue
			? linkedinValue.startsWith('http')
				? linkedinValue
				: `https://www.linkedin.com/in/${linkedinHandle}`
			: ''
	);

	function nextSlide() {
		currentSlide = (currentSlide + 1) % totalSlides;
	}

	function previousSlide() {
		currentSlide = (currentSlide - 1 + totalSlides) % totalSlides;
	}

	function goToSlide(slideIndex: number) {
		currentSlide = slideIndex;
	}
</script>

<div
	class="team-card"
>
	<div class="carousel-header">
		<div class="carousel-controls">
			<button class="carousel-btn" onclick={previousSlide} aria-label="Card anterior">
				<ChevronLeft size={12} />
			</button>
			<button class="carousel-btn" onclick={nextSlide} aria-label="Próximo card">
				<ChevronRight size={12} />
			</button>
		</div>
	</div>

	{#if currentSlide === 0}
		<div class="member-slide">
			<div class="team-avatar-wrap">
				{#if imageError}
					<div class="fallback-avatar">
						<svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
							<path
								fill-rule="evenodd"
								d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z"
								clip-rule="evenodd"
							/>
						</svg>
					</div>
				{:else}
					<img
						src={avatarUrl}
						alt={name}
						class="team-avatar"
						loading="lazy"
						onerror={() => (imageError = true)}
					/>
				{/if}
			</div>

			<h4 class="team-name">{name}</h4>
			<span class="team-role">Desenvolvedor</span>
		</div>
	{:else if currentSlide === 1}
		<div class="member-slide">
			<h4 class="slide-title">Especialidades</h4>
			<ul class="specialties-list">
				{#if specialties.length > 0}
					{#each specialties as specialty}
						<li>{specialty}</li>
					{/each}
				{:else}
					<li>Especialidades não informadas</li>
				{/if}
			</ul>
		</div>
	{:else}
		<div class="member-slide">
			<h4 class="slide-title">Contato</h4>
			<div class="contact-list">
				<div class="contact-item">
					<Github size={16} />
					<a href={githubUrl} target="_blank" rel="noopener noreferrer">@{githubUsername}</a>
				</div>
				<div class="contact-item">
					<Linkedin size={16} />
					{#if linkedinUrl}
						<a href={linkedinUrl} target="_blank" rel="noopener noreferrer">
							{linkedinValue.startsWith('http') ? 'Perfil no LinkedIn' : `@${linkedinHandle}`}
						</a>
					{:else}
						<span>LinkedIn não informado</span>
					{/if}
				</div>
				<div class="contact-item">
					<Mail size={16} />
					{#if email}
						<a href={`mailto:${email}`}>{email}</a>
					{:else}
						<span>E-mail não informado</span>
					{/if}
				</div>
			</div>
		</div>
	{/if}

	<div class="carousel-dots" aria-label="Navegação do carrossel">
		{#each Array(totalSlides) as _, index}
			<button
				class="dot"
				class:active={currentSlide === index}
				onclick={() => goToSlide(index)}
				aria-label={`Ir para card ${index + 1}`}
			></button>
		{/each}
	</div>
</div>

<style>
	.team-card {
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		padding: 1rem;
		display: flex;
		flex-direction: column;
		justify-content: space-between;
		min-height: 280px;
		transition: transform 0.2s ease;
	}

	.team-card:hover {
		transform: scale(1.05);
	}

	.carousel-header {
		display: flex;
		align-items: center;
		justify-content: flex-end;
		margin-bottom: 0.625rem;
	}

	.carousel-controls {
		display: flex;
		gap: 0.375rem;
	}

	.carousel-btn {
		width: 22px;
		height: 22px;
		border-radius: 999px;
		border: 1px solid rgba(255, 255, 255, 0.2);
		background: rgba(255, 255, 255, 0.08);
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.carousel-btn:hover {
		background: rgba(255, 255, 255, 0.2);
	}

	.member-slide {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-align: center;
		flex: 1;
		gap: 0.5rem;
	}

	.team-avatar-wrap {
		width: 100px;
		height: 100px;
		margin-bottom: 0.5rem;
	}

	.fallback-avatar {
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #374151;
		border-radius: 50%;
	}

	.team-avatar {
		width: 100%;
		height: 100%;
		border-radius: 50%;
		object-fit: cover;
		background: #374151;
	}

	.team-name {
		font-family: 'Permanent Marker', cursive;
		color: white;
		font-size: clamp(0.875rem, 2vw, 1.25rem);
		text-align: center;
		margin: 0;
	}

	.team-role {
		color: #aeadad;
		font-size: clamp(0.75rem, 1.5vw, 1rem);
		letter-spacing: 0.5px;
	}

	.slide-title {
		color: white;
		font-size: 1rem;
		font-weight: 700;
		margin-bottom: 0.25rem;
	}

	.specialties-list {
		list-style: none;
		padding: 0;
		margin: 0;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.specialties-list li {
		color: #f3f4f6;
		font-size: 0.875rem;
		padding: 0.25rem 0.625rem;
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.12);
	}

	.contact-list {
		display: flex;
		flex-direction: column;
		gap: 0.625rem;
	}

	.contact-item {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.375rem;
		color: #f3f4f6;
		font-size: 0.8125rem;
	}

	.contact-item a {
		color: #f3f4f6;
		text-decoration: none;
	}

	.contact-item a:hover {
		text-decoration: underline;
	}

	.carousel-dots {
		display: flex;
		justify-content: center;
		gap: 0.375rem;
		margin-top: 0.75rem;
	}

	.dot {
		width: 8px;
		height: 8px;
		border-radius: 999px;
		border: none;
		cursor: pointer;
		background: rgba(255, 255, 255, 0.35);
	}

	.dot.active {
		background: #f9fafb;
	}
</style>
