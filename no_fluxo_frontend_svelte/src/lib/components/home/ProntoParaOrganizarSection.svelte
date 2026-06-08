<script lang="ts">
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/stores/auth';
	import { Button } from '$lib/components/ui/button';
	import { scrollReveal } from '$lib/actions/scrollReveal';
	import { GraduationCap } from 'lucide-svelte';

	function handleClick() {
		const user = $currentUser;
		if (user) {
			if (user.dadosFluxograma) {
				goto('/meu-fluxograma');
			} else {
				goto('/upload-historico');
			}
		} else {
			goto('/signup');
		}
	}
</script>

<section class="pronto-section nf-gradient-section">
	<div class="pronto-inner" use:scrollReveal={{ delay: 0 }}>
		<div class="pronto-icon" aria-hidden="true">
			<GraduationCap class="h-7 w-7 text-white" stroke-width="1.75" />
		</div>

		<h2 class="section-heading" use:scrollReveal={{ delay: 80 }}>
			Pronto para organizar seu fluxo?
		</h2>

		<p class="pronto-lead" use:scrollReveal={{ delay: 160 }}>
			Crie sua conta, envie seu histórico e use o mesmo ecossistema visual em fluxograma, upload e
			assistente.
		</p>

		<div use:scrollReveal={{ delay: 240 }}>
			<Button
				size="lg"
				class="nf-cta-glow nf-cta-glow-hover rounded-xl px-8 uppercase tracking-wide"
				onclick={handleClick}
			>
				Começar agora
			</Button>
		</div>

		<p class="pronto-note" use:scrollReveal={{ delay: 300 }}>
			<span class="note-dot" aria-hidden="true"></span>
			Acesso gratuito · Sem cadastro obrigatório para consultar
		</p>
	</div>
</section>

<style>
	.pronto-section {
		padding: clamp(4rem, 9vw, 5.5rem) 1.5rem;
	}

	.pronto-inner {
		max-width: 600px;
		margin: 0 auto;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0;
		text-align: center;
	}

	.pronto-icon {
		width: 56px;
		height: 56px;
		border-radius: 16px;
		background: hsl(var(--primary));
		border: 1px solid hsl(var(--primary) / 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 1.5rem;
		box-shadow:
			0 0 28px hsl(var(--primary) / 0.38),
			inset 0 1px 0 hsl(0 0% 100% / 0.14);
	}

	.section-heading {
		font-size: clamp(1.375rem, 3vw, 1.875rem);
		font-weight: 800;
		letter-spacing: -0.03em;
		color: hsl(var(--foreground));
		margin: 0 0 1rem;
		line-height: 1.2;
	}

	.pronto-lead {
		color: hsl(var(--muted-foreground));
		font-size: clamp(0.875rem, 1.5vw, 1rem);
		max-width: 480px;
		margin: 0 0 2rem;
		line-height: 1.65;
	}

	.pronto-note {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		margin-top: 1rem;
		font-size: 0.75rem;
		color: hsl(var(--muted-foreground) / 0.7);
		letter-spacing: 0.02em;
	}

	.note-dot {
		width: 5px;
		height: 5px;
		border-radius: 50%;
		background: hsl(var(--primary) / 0.6);
		flex-shrink: 0;
	}
</style>
