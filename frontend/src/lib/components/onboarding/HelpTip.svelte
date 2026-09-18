<script lang="ts">
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { HelpCircle } from 'lucide-svelte';
	import type { Snippet } from 'svelte';

	/**
	 * Dica de ajuda no padrão do DS. Sem `children`, renderiza o ícone "?" padrão;
	 * com `children`, vira wrapper de qualquer gatilho (botão, chip, título).
	 */
	let {
		text,
		title = '',
		side = 'top',
		children,
		class: className = ''
	}: {
		text: string;
		title?: string;
		side?: 'top' | 'bottom' | 'left' | 'right';
		children?: Snippet;
		class?: string;
	} = $props();
</script>

<Tooltip.Provider delayDuration={200}>
	<Tooltip.Root>
		{#if children}
			<!--
				Com gatilho próprio o Trigger vira <span> (snippet `child`): o conteúdo
				normalmente já é um <button>/<a>, e botão dentro de botão é HTML inválido
				— o navegador desmonta a árvore e o clique original para de funcionar.
			-->
			<Tooltip.Trigger>
				{#snippet child({ props })}
					<span {...props} class={`help-trigger-wrap ${className}`}>
						{@render children()}
					</span>
				{/snippet}
			</Tooltip.Trigger>
		{:else}
			<Tooltip.Trigger class={`help-trigger ${className}`} aria-label={title || text}>
				<HelpCircle class="h-3.5 w-3.5 text-white/40 transition-colors hover:text-white/80" />
			</Tooltip.Trigger>
		{/if}
		<Tooltip.Content
			{side}
			sideOffset={6}
			class="nf-card-surface z-[140] max-w-[260px] border-white/12 bg-zinc-950/95 px-3 py-2 text-white shadow-xl backdrop-blur-md"
			arrowClasses="bg-zinc-950 border-white/12"
		>
			{#if title}
				<p class="mb-0.5 text-[12px] font-semibold text-white">{title}</p>
			{/if}
			<p class="text-[11px] leading-relaxed text-white/70">{text}</p>
		</Tooltip.Content>
	</Tooltip.Root>
</Tooltip.Provider>

<style>
	:global(.help-trigger) {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		cursor: help;
	}

	:global(.help-trigger-wrap) {
		display: inline-flex;
		align-items: center;
	}
</style>
