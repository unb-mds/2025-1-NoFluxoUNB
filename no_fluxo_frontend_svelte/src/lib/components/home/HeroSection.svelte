<script lang="ts">
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/stores/auth';

	let isHovered = $state(false);

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
</script>

<section class="hero-section">
	<div class="hero-content">
		<div class="hero-text">
			<h1 class="hero-title">
				TENHA SEU<br />
				FLUXOGRAMA<br />
				MUITO <span class="text-pink-400">RÁPIDO</span>
			</h1>

			<p class="hero-description">
				O NoFluxo UNB te ajuda a ver o fluxograma do seu curso e ainda permite montar um
				<span class="hero-card-strong">fluxograma personalizado com IA</span> quando você faz login e envia seu histórico.
			</p>

			<button
				class="hero-btn"
				onmouseenter={() => (isHovered = true)}
				onmouseleave={() => (isHovered = false)}
				onclick={handleCTAClick}
				style="transform: scale({isHovered ? 1.05 : 1});"
			>
				ACESSE NOSSO SISTEMA
			</button>
		</div>

		<div class="hero-cards">
			<div class="hero-card">
				<h3 class="hero-card-title">Consultar como <span class="hero-card-accent">visitante</span></h3>
				<p class="hero-card-text">
					Você pode <span class="hero-card-strong">ver fluxogramas de vários cursos</span> sem login, ideal para
					<span class="hero-card-strong">consulta rápida</span> e comparação.
				</p>
			</div>
			<div class="hero-card">
				<h3 class="hero-card-title">Recursos <span class="hero-card-accent">exclusivos</span> com login</h3>
				<p class="hero-card-text">
					Faça login, envie seu <span class="hero-card-strong">histórico em PDF</span> e use a IA como
					<span class="hero-card-strong">ferramenta de auxílio para sugestão de matérias</span>. Além disso,
					você <span class="hero-card-strong">salva progresso</span>, marca disciplinas e aponta
					<span class="hero-card-strong" style="color: #f97316;"> matérias, pré-requisitos e equivalências, assim como co-requisitos</span>.
				</p>
			</div>
		</div>
	</div>
</section>

<style>
	.hero-section {
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(0, 0, 0, 0.3);
		padding: 5rem 1.25rem 2.5rem;
	}

	.hero-content {
		max-width: 1200px;
		width: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 2rem;
	}

	.hero-text {
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
	}

	.hero-title {
		font-family: 'Permanent Marker', cursive;
		font-size: clamp(1.8rem, 6vw, 3.4rem);
		color: white;
		font-weight: bold;
		line-height: 1.15;
		text-shadow: 3px 3px 6px rgba(0, 0, 0, 0.3);
		margin-bottom: 1.25rem;
	}

	.hero-description {
		font-family: 'Poppins', sans-serif;
		color: rgba(255, 255, 255, 0.95);
		font-size: clamp(0.85rem, 2.4vw, 1.1rem);
		max-width: 640px;
		line-height: 1.5;
		letter-spacing: 0.4px;
		margin-bottom: 2rem;
	}

	.hero-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		background: linear-gradient(to right, #2296ee, #1d4ed8);
		color: white;
		font-family: 'Permanent Marker', cursive;
		font-size: clamp(0.875rem, 2vw, 1.25rem);
		padding: 0.75rem 2.5rem;
		border-radius: 32px;
		border: none;
		cursor: pointer;
		letter-spacing: 2px;
		box-shadow: 0 4px 20px rgba(29, 78, 216, 0.3);
		transition: transform 0.2s ease;
	}

	.hero-cards {
		display: grid;
		grid-template-columns: 1fr;
		gap: 0.9rem;
		width: 100%;
		max-width: 420px;
	}

	.hero-card {
		background: rgba(0, 0, 0, 0.5);
		border-radius: 16px;
		padding: 1rem 1.25rem;
		border: 1px solid rgba(255, 255, 255, 0.12);
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.25);
	}

	.hero-card-title {
		font-family: 'Permanent Marker', cursive;
		color: white;
		font-size: 0.95rem;
		margin-bottom: 0.35rem;
	}

	.hero-card-text {
		font-family: 'Poppins', sans-serif;
		color: rgba(229, 231, 235, 0.95);
		font-size: 0.8rem;
		line-height: 1.4;
	}

	.hero-card-accent {
		color: #f97316;
	}

	.hero-card-strong {
		color: #e5e7eb;
		font-weight: 600;
	}

	@media (min-width: 1024px) {
		.hero-content {
			flex-direction: row;
			align-items: flex-start;
			gap: 3rem;
		}

		.hero-text {
			flex: 1;
			align-items: flex-start;
			text-align: left;
		}

		.hero-cards {
			max-width: 360px;
		}
	}

	@media (min-width: 768px) {
		.hero-text {
			align-items: flex-start;
			text-align: left;
		}
	}
</style>
