<script lang="ts">
	import { X } from 'lucide-svelte';
	import { clickOutside } from '$lib/actions/clickOutside';
	import { fade, fly } from 'svelte/transition';

	interface Props {
		open: boolean;
		onclose: () => void;
	}

	let { open, onclose }: Props = $props();

	const steps = [
		{
			number: 1,
			title: 'Acesse o SIGAA',
			image: '/help/tela_de_cadastro.png',
			alt: 'Tela de login do SIGAA'
		},
		{
			number: 2,
			title: 'Selecione "Emitir Histórico"',
			description: 'No menu lateral, clique em Ensino e depois em Emitir Histórico.',
			image: '/help/emitir_historico.png',
			alt: 'Menu Emitir Histórico no SIGAA'
		},
		{
			number: 3,
			title: 'Faça o upload do PDF para o NoFluxoUNB',
			description:
				'Salve o arquivo PDF gerado em seu computador e faça o upload nesta página.',
			image: '/help/historico_baixado.png',
			alt: 'Exemplo de histórico acadêmico gerado'
		}
	];

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onclose();
	}
</script>

{#if open}
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<!-- svelte-ignore a11y_no_noninteractive_tabindex -->
	<div
		class="overlay"
		role="dialog"
		aria-modal="true"
		aria-label="Como obter seu histórico acadêmico"
		tabindex="0"
		transition:fade={{ duration: 200 }}
		onkeydown={handleKeydown}
	>
		<div
			class="modal"
			use:clickOutside={{ onClickOutside: onclose }}
			transition:fly={{ y: 30, duration: 250 }}
		>
			<!-- Header -->
			<div class="flex items-center justify-between border-b border-white/10 px-6 py-4">
				<h2 class="text-lg font-bold text-white md:text-xl">
					Como obter seu histórico acadêmico
				</h2>
				<button
					type="button"
					class="rounded-lg p-1.5 text-gray-400 transition-colors hover:bg-white/10 hover:text-white"
					onclick={onclose}
					aria-label="Fechar"
				>
					<X class="h-5 w-5" />
				</button>
			</div>

			<!-- Steps -->
			<div class="space-y-6 px-6 py-5">
				{#each steps as step}
					<div class="step-block">
						<div class="flex items-start gap-3">
							<div class="step-number">
								{step.number}
							</div>
							<div>
								<h3 class="text-sm font-semibold text-white md:text-base">
									{step.title}
								</h3>
								{#if step.number === 1}
									<p class="mt-0.5 text-sm text-gray-400">
										Entre no
										<a
											href="https://sig.unb.br/sigaa/"
											target="_blank"
											rel="noopener noreferrer"
											class="font-medium text-blue-400 underline hover:text-blue-300"
										>
											SIGAA
										</a>
										com seu login e senha institucional.
									</p>
								{:else if step.description}
									<p class="mt-0.5 text-sm text-gray-400">{step.description}</p>
								{/if}
							</div>
						</div>
						{#if step.image}
							<div class="mt-3 flex justify-center">
								<img
									src={step.image}
									alt={step.alt}
									class="step-image"
									loading="lazy"
								/>
							</div>
						{/if}
					</div>
				{/each}
			</div>

			<!-- Footer -->
			<div class="border-t border-white/10 px-6 py-4">
				<button
					type="button"
					class="entendi-btn"
					onclick={onclose}
				>
					Entendi
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	@reference 'tailwindcss';

	.overlay {
		@apply fixed inset-0 z-50 flex items-center justify-center p-4;
		background: rgba(0, 0, 0, 0.7);
		backdrop-filter: blur(4px);
	}

	.modal {
		@apply w-full max-w-lg overflow-hidden rounded-2xl md:max-w-xl;
		max-height: 90vh;
		overflow-y: auto;
		background: rgba(30, 30, 30, 0.95);
		border: 1px solid rgba(255, 255, 255, 0.1);
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
	}

	.step-number {
		@apply flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-sm font-bold text-white;
		background: linear-gradient(135deg, #6c63ff, #e91e63);
	}

	.step-block {
		@apply rounded-xl border border-white/5 bg-white/3 p-4;
	}

	.step-image {
		@apply max-w-70 rounded-lg border border-white/10 shadow-lg md:max-w-100;
	}

	.entendi-btn {
		@apply w-full rounded-lg px-4 py-2.5 text-sm font-medium text-white transition-colors;
		background: linear-gradient(135deg, rgba(108, 99, 255, 0.4), rgba(233, 30, 99, 0.4));
	}

	.entendi-btn:hover {
		background: linear-gradient(135deg, rgba(108, 99, 255, 0.6), rgba(233, 30, 99, 0.6));
	}
</style>
