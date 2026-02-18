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
			description: 'Entre no portal SIGAA da UnB com seu login e senha.'
		},
		{
			number: 2,
			title: 'Vá para Ensino > Histórico',
			description: 'No menu superior, clique em "Ensino" e depois em "Histórico".'
		},
		{
			number: 3,
			title: 'Emita o PDF',
			description: 'Clique no botão "Emitir Histórico" ou "Gerar PDF" para gerar o documento.'
		},
		{
			number: 4,
			title: 'Baixe o arquivo',
			description: 'Salve o arquivo PDF no seu computador e faça o upload aqui.'
		}
	];

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onclose();
	}
</script>

{#if open}
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div
		class="overlay"
		role="dialog"
		aria-modal="true"
		aria-label="Como obter seu histórico acadêmico"
		transition:fade={{ duration: 200 }}
		onkeydown={handleKeydown}
	>
		<div
			class="modal"
			use:clickOutside
			onclickoutside={onclose}
			transition:fly={{ y: 30, duration: 250 }}
		>
			<!-- Header -->
			<div class="flex items-center justify-between border-b border-white/10 px-6 py-4">
				<h2 class="text-lg font-bold text-white">Como obter seu histórico</h2>
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
			<div class="space-y-4 px-6 py-5">
				{#each steps as step}
					<div class="flex gap-4">
						<div class="step-number">
							{step.number}
						</div>
						<div>
							<h3 class="text-sm font-semibold text-white">{step.title}</h3>
							<p class="mt-0.5 text-sm text-gray-400">{step.description}</p>
						</div>
					</div>
				{/each}
			</div>

			<!-- Footer -->
			<div class="border-t border-white/10 px-6 py-4">
				<button
					type="button"
					class="w-full rounded-lg bg-white/10 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-white/20"
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
		@apply w-full max-w-md overflow-hidden rounded-2xl;
		background: rgba(30, 30, 30, 0.95);
		border: 1px solid rgba(255, 255, 255, 0.1);
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
	}

	.step-number {
		@apply flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-sm font-bold text-white;
		background: linear-gradient(135deg, #6c63ff, #e91e63);
	}
</style>
