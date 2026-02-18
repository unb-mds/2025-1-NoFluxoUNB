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
				O NO FLUXO UNB TE AJUDA A VER O FLUXOGRAMA DO SEU CURSO E AINDA TE PERMITE ADICIONAR
				MATÉRIAS OPTATIVAS DE ACORDO COM SUAS ÁREAS DE INTERESSE!
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

		<div class="hero-illustration">
			<img
				src="/icons/computer_phone.svg"
				alt="Ilustração NoFluxo"
				class="w-full h-auto max-w-md drop-shadow-2xl"
				onerror={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
			/>
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
		padding: 6rem 1.5rem 3rem;
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
		font-size: clamp(2rem, 6vw, 4rem);
		color: white;
		font-weight: bold;
		line-height: 1.15;
		text-shadow: 3px 3px 6px rgba(0, 0, 0, 0.3);
		margin-bottom: 1.5rem;
	}

	.hero-description {
		font-family: 'Poppins', sans-serif;
		color: rgba(255, 255, 255, 0.95);
		font-size: clamp(0.875rem, 2vw, 1.25rem);
		max-width: 700px;
		line-height: 1.6;
		letter-spacing: 0.5px;
		margin-bottom: 2.5rem;
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

	.hero-illustration {
		display: none;
	}

	@media (min-width: 1024px) {
		.hero-content {
			flex-direction: row;
			gap: 3rem;
		}

		.hero-text {
			flex: 1;
			align-items: flex-start;
			text-align: left;
		}

		.hero-illustration {
			display: flex;
			flex: 1;
			justify-content: flex-end;
		}
	}

	@media (min-width: 768px) {
		.hero-text {
			align-items: flex-start;
			text-align: left;
		}
	}
</style>
