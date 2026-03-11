<script lang="ts">
	import { Home } from 'lucide-svelte';
</script>

<a href="/" class="home-link" title="Voltar ao início">
	<Home class="h-5 w-5" />
</a>

<style>
	.home-link {
		position: fixed;
		top: 1rem;
		right: 1rem;
		z-index: 50;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		border-radius: 10px;
		background: rgba(0, 0, 0, 0.25);
		color: rgba(255, 255, 255, 0.9);
		backdrop-filter: blur(8px);
		transition: background 0.2s, color 0.2s, transform 0.15s;
	}
	.home-link:hover {
		background: rgba(0, 0, 0, 0.4);
		color: #fff;
		transform: scale(1.05);
	}
</style>
