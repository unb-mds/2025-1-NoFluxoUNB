<script lang="ts">
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/stores/auth';
	import { Zap, Sparkles, Eye, Lock, User, Star } from 'lucide-svelte';

	function handleCTAClick() {
		const user = $currentUser;
		if (user) {
			if (user.dadosFluxograma) {
				goto('/meu-fluxograma');
			} else {
				goto('/upload-historico');
			}
		} else {
			goto('/login');
		}
	}

	const stats = [
		{ value: '10+', label: 'Cursos' },
		{ value: 'FGA', label: 'UnB' },
		{ value: 'IA', label: 'Integrada' }
	];
</script>

<section
	class="relative z-[1] flex min-h-[min(calc(100dvh-5.5rem),960px)] items-start justify-center overflow-hidden"
>
	<!-- Video background -->
	<div class="hero-video-wrap" aria-hidden="true">
		<video
			class="hero-video"
			src="/videos/hero-bg.mp4"
			autoplay
			muted
			loop
			playsinline
			disablepictureinpicture
		></video>
		<div class="hero-video-overlay"></div>
	</div>
	<div
		class="relative z-10 mx-auto grid w-full max-w-[1180px] grid-cols-1 gap-12 px-6 py-10 lg:grid-cols-[55fr_45fr] lg:px-16 lg:py-14"
	>
		<!-- Left column: text -->
		<div class="flex flex-col items-center text-center lg:items-start lg:text-left">
			<!-- Shimmer badge -->
			<p
				class="nf-shimmer-badge mb-5 inline-flex items-center gap-2 rounded-full border border-primary/50 px-4 py-1.5 text-[11px] font-semibold uppercase tracking-widest text-primary nf-hero-in"
				style="--nf-delay: 0"
			>
				<Sparkles class="size-[0.9rem] shrink-0 text-primary" aria-hidden="true" stroke-width="2.25" />
				<span>Plataforma inteligente da UNB</span>
			</p>

			<!-- Headline -->
			<h1
				class="mb-5 font-black uppercase leading-[1.0] tracking-tight text-[clamp(44px,5.5vw,68px)] nf-hero-in"
				style="--nf-delay: 60"
			>
				<span class="block text-foreground">Tenha seu</span>
				<span class="block text-primary">fluxograma</span>
				<span class="block text-foreground">muito</span>
				<span class="block text-primary">rápido</span>
			</h1>

			<!-- Description -->
			<p
				class="mb-7 max-w-[460px] text-[15px] leading-relaxed text-muted-foreground nf-hero-in"
				style="--nf-delay: 120"
			>
				Visualize, monte e personalize fluxogramas de qualquer curso com o poder da IA. Mais
				agilidade para estudar, entender e avançar.
			</p>

			<!-- CTA -->
			<button
				type="button"
				class="nf-cta-glow nf-cta-glow-hover inline-flex w-fit items-center justify-center gap-[0.65rem] rounded-xl bg-primary px-9 py-[18px] text-sm font-bold uppercase tracking-widest text-primary-foreground transition-all duration-150 hover:brightness-110 active:scale-[0.97] nf-hero-in"
				style="--nf-delay: 180"
				onclick={handleCTAClick}
			>
				<Zap class="size-5 shrink-0 opacity-95" aria-hidden="true" stroke-width="2.25" />
				Acessar nosso sistema
			</button>

			<!-- Stats row -->
			<div class="hero-stats nf-hero-in" style="--nf-delay: 260" aria-label="Métricas da plataforma">
				{#each stats as stat, i}
					{#if i > 0}
						<div class="stat-divider" aria-hidden="true"></div>
					{/if}
					<div class="stat-item">
						<span class="stat-value">{stat.value}</span>
						<span class="stat-label">{stat.label}</span>
					</div>
				{/each}
			</div>
		</div>

		<!-- Right column: info cards -->
		<div class="flex flex-col gap-4 nf-hero-in" style="--nf-delay: 180" aria-label="Duas formas de usar o NoFluxo">
			<article class="hero-info-card">
				<div class="hero-info-card-icon" aria-hidden="true">
					<Eye class="hero-info-card-icon-svg" stroke-width="2" />
				</div>
				<h2 class="hero-info-card-title">
					<span class="text-foreground">Consultar como</span>{' '}
					<span class="text-primary">visitante</span>
				</h2>
				<p class="hero-info-card-body">
					Explore fluxogramas de qualquer curso da UnB sem fazer login. Faça a sua consulta rápida
					sem cadastro.
				</p>
				<p class="hero-info-card-pill">
					<User class="hero-info-card-pill-icon" stroke-width="2" aria-hidden="true" />
					<span>Acesso livre e imediato</span>
				</p>
			</article>

			<article class="hero-info-card">
				<div class="hero-info-card-icon" aria-hidden="true">
					<Lock class="hero-info-card-icon-svg hero-info-card-icon-svg--sm" stroke-width="2" />
				</div>
				<h2 class="hero-info-card-title">
					<span class="text-foreground">Recursos</span>{' '}
					<span class="text-primary">exclusivos com login</span>
				</h2>
				<p class="hero-info-card-body">
					Faça upload do histórico em PDF, ganhe sugestões com IA e salve seu progresso em um só
					lugar.
				</p>
				<p class="hero-info-card-pill">
					<Star class="hero-info-card-pill-icon" stroke-width="2" aria-hidden="true" />
					<span>Potencialize seus estudos</span>
				</p>
			</article>
		</div>
	</div>
</section>

<style>
	/* Video background */
	.hero-video-wrap {
		position: absolute;
		inset: 0;
		z-index: 0;
		overflow: hidden;
	}

	.hero-video {
		position: absolute;
		inset: 0;
		width: 100%;
		height: 100%;
		object-fit: cover;
		object-position: center;
		opacity: 0.6;
	}

	.hero-video-overlay {
		position: absolute;
		inset: 0;
		background:
			radial-gradient(ellipse 70% 60% at 50% 50%, transparent 0%, hsl(240 16% 4% / 0.3) 70%),
			linear-gradient(to bottom, hsl(240 16% 4% / 0.15) 0%, hsl(240 16% 4% / 0.65) 100%);
	}

	/* Stats row */
	.hero-stats {
		display: flex;
		align-items: center;
		gap: 0;
		margin-top: 1.5rem;
		padding: 0.75rem 1.25rem;
		border-radius: 12px;
		background: hsl(var(--card) / 0.6);
		border: 1px solid hsl(var(--border) / 0.6);
		width: fit-content;
	}

	.stat-item {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 2px;
		padding: 0 1rem;
	}

	.stat-value {
		font-size: 1.25rem;
		font-weight: 800;
		letter-spacing: -0.03em;
		color: hsl(var(--foreground));
		line-height: 1.1;
	}

	.stat-label {
		font-size: 0.6875rem;
		font-weight: 500;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: hsl(var(--muted-foreground));
	}

	.stat-divider {
		width: 1px;
		height: 28px;
		background: hsl(var(--border) / 0.8);
		flex-shrink: 0;
	}

	/* Info cards (same as before) */
	.hero-info-card {
		display: flex;
		flex-direction: column;
		gap: 12px;
		background: hsl(var(--card));
		border: 1px solid hsl(var(--primary) / 0.28);
		border-radius: 16px;
		padding: 24px;
		text-align: left;
		box-shadow:
			0 0 0 1px hsl(var(--primary) / 0.12),
			0 0 12px hsl(var(--primary) / 0.14),
			inset 0 1px 0 hsl(255 100% 100% / 0.06);
		transition:
			transform 0.2s ease,
			border-color 0.2s ease,
			box-shadow 0.2s ease;
	}

	.hero-info-card:hover {
		transform: translateY(-2px);
		border-color: hsl(var(--primary) / 0.6);
		box-shadow:
			0 0 0 1px hsl(var(--primary) / 0.26),
			0 0 20px hsl(var(--primary) / 0.26),
			0 0 34px hsl(var(--primary) / 0.14),
			inset 0 1px 0 hsl(255 100% 100% / 0.12);
	}

	.hero-info-card-icon {
		width: 52px;
		height: 52px;
		border-radius: 50%;
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		background: hsl(var(--primary));
		border: 2px solid hsl(var(--primary) / 0.55);
		color: #ffffff;
		box-shadow:
			0 0 20px hsl(var(--primary) / 0.45),
			inset 0 1px 0 hsl(0 0% 100% / 0.18);
	}

	.hero-info-card-icon :global(.hero-info-card-icon-svg) {
		width: 1.75rem;
		height: 1.75rem;
		flex-shrink: 0;
		color: #ffffff;
		stroke: #ffffff;
	}

	.hero-info-card-icon :global(.hero-info-card-icon-svg--sm) {
		width: 1.5rem;
		height: 1.5rem;
		color: #ffffff;
		stroke: #ffffff;
	}

	.hero-info-card-title {
		margin: 0;
		font-size: 0.875rem;
		font-weight: 700;
		line-height: 1.35;
		letter-spacing: 0.04em;
		text-transform: uppercase;
	}

	.hero-info-card-body {
		margin: 0;
		font-size: 13px;
		line-height: 1.625;
		color: hsl(var(--muted-foreground));
	}

	.hero-info-card-pill {
		margin: 0;
		display: inline-flex;
		align-items: center;
		gap: 6px;
		width: fit-content;
		border: 1px solid hsl(var(--primary) / 0.32);
		border-radius: 999px;
		padding: 0.34rem 0.8rem;
		font-size: 12px;
		font-weight: 500;
		letter-spacing: 0.01em;
		color: hsl(var(--foreground));
		background: linear-gradient(
			135deg,
			hsl(var(--primary) / 0.2) 0%,
			hsl(var(--primary) / 0.09) 40%,
			hsl(var(--card) / 0.65) 100%
		);
		box-shadow:
			0 0 0 1px hsl(var(--primary) / 0.1),
			0 0 12px hsl(var(--primary) / 0.16),
			inset 0 1px 0 hsl(0 0% 100% / 0.08);
	}

	.hero-info-card-pill :global(.hero-info-card-pill-icon) {
		width: 1rem;
		height: 1rem;
		flex-shrink: 0;
		color: hsl(var(--foreground));
	}
</style>
