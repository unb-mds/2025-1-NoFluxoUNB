<script lang="ts">
	import { goto } from '$app/navigation';

	let isHovered = $state(false);

	function handleClick() {
		goto('/signup');
	}
</script>

<section class="pronto-section">
	<h2 class="section-title">PRONTO PARA ORGANIZAR SEU FLUXO?</h2>
	<p class="pronto-desc">
		Não perca mais tempo tentando entender seu fluxograma. O NoFluxo UNB torna tudo mais simples e
		visual para você planejar sua jornada acadêmica.
	</p>
	<button
		class="hero-btn"
		onmouseenter={() => (isHovered = true)}
		onmouseleave={() => (isHovered = false)}
		onclick={handleClick}
		style="transform: scale({isHovered ? 1.05 : 1});"
	>
		COMEÇAR AGORA
	</button>
</section>

<style>
	.section-title {
		font-family: 'Permanent Marker', cursive;
		color: white;
		font-size: clamp(1.5rem, 4vw, 2rem);
		text-align: center;
		letter-spacing: 1.5px;
		text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
		margin-bottom: 1.5rem;
	}

	.pronto-section {
		padding: 4rem 1.5rem;
		background: rgba(0, 0, 0, 0.3);
		text-align: center;
		display: flex;
		flex-direction: column;
		align-items: center;
	}

	.pronto-desc {
		color: #d1d5db;
		font-size: clamp(0.875rem, 2vw, 1rem);
		max-width: 600px;
		margin: 0 auto 2rem;
		line-height: 1.6;
		letter-spacing: 1.2px;
		text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.4);
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
</style>
