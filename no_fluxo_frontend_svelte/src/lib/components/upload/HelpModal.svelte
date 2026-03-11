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

	// Bloquear scroll do body quando o modal está aberto
	$effect(() => {
		if (open) {
			const prev = document.body.style.overflow;
			document.body.style.overflow = 'hidden';
			return () => {
				document.body.style.overflow = prev;
			};
		}
	});
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
			<div class="modal-header">
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
			<div class="modal-scroll-area space-y-6">
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
			<div class="modal-footer">
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
		overflow: hidden;
		background: rgba(0, 0, 0, 0.7);
		backdrop-filter: blur(4px);
	}

	.modal {
		@apply w-full max-w-lg rounded-2xl md:max-w-xl;
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		display: flex;
		flex-direction: column;
		max-height: 90vh;
		overflow: hidden;
		background: rgba(30, 30, 30, 0.95);
		border: 1px solid rgba(255, 255, 255, 0.1);
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
	}
	.modal-header {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: space-between;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
		padding: 1rem 1.5rem;
	}
	.modal-scroll-area {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		overscroll-behavior: contain;
		-webkit-overflow-scrolling: touch;
		padding: 1.25rem 1.5rem;
	}
	.modal-footer {
		flex-shrink: 0;
		border-top: 1px solid rgba(255, 255, 255, 0.1);
		padding: 1rem 1.5rem;
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
