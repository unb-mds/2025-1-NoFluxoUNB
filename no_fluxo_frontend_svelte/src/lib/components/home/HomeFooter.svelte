<script lang="ts">
	import { Github } from 'lucide-svelte';

	const currentYear = new Date().getFullYear();

	const links = [
		{ label: 'Home', href: '/' },
		{ label: 'Fluxogramas', href: '/fluxogramas' },
		{ label: 'Sobre', href: '/#sobre-nos' }
	];

	const socialLinks = [
		{
			icon: Github,
			href: 'https://github.com/unb-mds/2025-1-NoFluxoUNB-2',
			label: 'GitHub'
		}
	];
</script>

<footer class="home-footer">
	<div class="footer-content">
		<div class="footer-brand">
			<p class="font-marker text-xl text-white">
				NO<span class="text-pink-500">FLUXO</span> UNB
			</p>
			<p class="footer-copyright">© {currentYear} NoFluxo UNB - Todos os direitos reservados</p>
		</div>

		<nav class="footer-links">
			{#each links as link}
				<a href={link.href} class="footer-link">
					{link.label}
				</a>
			{/each}
		</nav>

		<div class="footer-social">
			{#each socialLinks as social}
				<a
					href={social.href}
					target="_blank"
					rel="noopener noreferrer"
					class="social-link"
					aria-label={social.label}
				>
					<social.icon class="h-5 w-5" />
				</a>
			{/each}
		</div>
	</div>
</footer>

<style>
	.home-footer {
		background: rgba(0, 0, 0, 0.7);
		border-top: 1px solid rgba(255, 255, 255, 0.1);
	}

	.footer-content {
		max-width: 1200px;
		margin: 0 auto;
		padding: 2rem 1rem;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1.5rem;
	}

	@media (min-width: 768px) {
		.footer-content {
			flex-direction: row;
			justify-content: space-between;
			padding: 2rem 2rem;
		}
	}

	.footer-brand {
		text-align: center;
	}

	@media (min-width: 768px) {
		.footer-brand {
			text-align: left;
		}
	}

	.footer-copyright {
		color: #9ca3af;
		font-size: 0.875rem;
		margin-top: 0.25rem;
	}

	.footer-links {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: 1rem;
	}

	@media (min-width: 768px) {
		.footer-links {
			gap: 1.5rem;
		}
	}

	.footer-link {
		color: #d1d5db;
		text-decoration: none;
		font-size: 0.875rem;
		transition: color 0.2s;
	}

	.footer-link:hover {
		color: white;
	}

	.footer-social {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.social-link {
		color: #d1d5db;
		transition: color 0.2s;
		padding: 0.5rem;
	}

	.social-link:hover {
		color: white;
	}
</style>
