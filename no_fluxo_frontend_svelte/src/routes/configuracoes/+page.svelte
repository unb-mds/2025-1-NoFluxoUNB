<script lang="ts">
	import { a11ySettings, resetA11y } from '$lib/stores/a11y';
	import {
		Settings,
		Contrast,
		ZapOff,
		Type,
		Pilcrow,
		Eye,
		RotateCcw,
		ExternalLink
	} from 'lucide-svelte';

	// Lista declarativa de toggles para evitar repeticao de markup acessivel.
	type ToggleKey = 'highContrast' | 'reducedMotion' | 'largeText' | 'dyslexicFont' | 'focusBold';

	const toggles: Array<{
		key: ToggleKey;
		label: string;
		description: string;
		icon: typeof Contrast;
	}> = [
		{
			key: 'highContrast',
			label: 'Alto contraste',
			description: 'Aumenta o contraste entre texto e fundo para melhor legibilidade.',
			icon: Contrast
		},
		{
			key: 'reducedMotion',
			label: 'Reduzir movimento',
			description: 'Desativa animacoes e transicoes nao essenciais.',
			icon: ZapOff
		},
		{
			key: 'largeText',
			label: 'Texto ampliado',
			description: 'Aumenta o tamanho da fonte em toda a aplicacao.',
			icon: Type
		},
		{
			key: 'dyslexicFont',
			label: 'Fonte para dislexia',
			description: 'Usa uma fonte projetada para facilitar a leitura por pessoas com dislexia.',
			icon: Pilcrow
		},
		{
			key: 'focusBold',
			label: 'Foco reforcado',
			description: 'Destaca com mais intensidade o elemento focado pelo teclado.',
			icon: Eye
		}
	];

	function toggle(key: ToggleKey) {
		a11ySettings.update((s) => ({ ...s, [key]: !s[key] }));
	}
</script>

<svelte:head>
	<title>Configuracoes | NoFluxo</title>
	<meta
		name="description"
		content="Configuracoes de acessibilidade do NoFluxo conforme WCAG 2.2 AA."
	/>
</svelte:head>

<main class="max-w-3xl mx-auto px-4 py-8">
	<header class="mb-8 flex items-center gap-3">
		<Settings class="w-8 h-8 text-emerald-400" aria-hidden="true" />
		<h1 class="text-3xl font-bold text-white">Configuracoes</h1>
	</header>

	<section
		aria-labelledby="a11y-heading"
		class="bg-zinc-900/50 border border-white/10 rounded-xl p-6"
	>
		<h2 id="a11y-heading" class="text-2xl font-semibold text-white mb-2">Acessibilidade</h2>
		<p class="text-sm text-zinc-300 mb-6">
			Ajustes que seguem as recomendacoes do WCAG 2.2 nivel AA para tornar a navegacao mais
			confortavel e inclusiva. As preferencias sao salvas localmente no seu navegador.
		</p>

		<ul class="space-y-3" role="list">
			{#each toggles as t (t.key)}
				{@const checked = $a11ySettings[t.key]}
				{@const labelId = `toggle-${t.key}-label`}
				{@const descId = `toggle-${t.key}-desc`}
				<li
					class="flex items-start justify-between gap-4 p-4 rounded-lg bg-zinc-950/40 border border-white/5"
				>
					<div class="flex items-start gap-3 min-w-0">
						<svelte:component
							this={t.icon}
							class="w-5 h-5 text-emerald-400 mt-0.5 shrink-0"
							aria-hidden="true"
						/>
						<div class="min-w-0">
							<span id={labelId} class="block text-white font-medium">{t.label}</span>
							<span id={descId} class="block text-sm text-zinc-400 mt-0.5">{t.description}</span>
						</div>
					</div>
					<button
						type="button"
						role="switch"
						aria-checked={checked}
						aria-labelledby={labelId}
						aria-describedby={descId}
						onclick={() => toggle(t.key)}
						class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-emerald-400 focus-visible:ring-offset-2 focus-visible:ring-offset-zinc-900 {checked
							? 'bg-emerald-500'
							: 'bg-zinc-700'}"
					>
						<span class="sr-only">{t.label}</span>
						<span
							aria-hidden="true"
							class="inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform {checked
								? 'translate-x-5'
								: 'translate-x-0.5'}"
						></span>
					</button>
				</li>
			{/each}
		</ul>

		<div class="mt-6 flex flex-wrap items-center gap-3">
			<button
				type="button"
				onclick={resetA11y}
				class="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-white text-sm font-medium border border-white/10 focus:outline-none focus-visible:ring-2 focus-visible:ring-emerald-400"
			>
				<RotateCcw class="w-4 h-4" aria-hidden="true" />
				Restaurar padroes
			</button>
		</div>
	</section>

	<footer class="mt-6 text-sm text-zinc-400">
		<a
			href="https://www.w3.org/WAI/standards-guidelines/wcag/"
			target="_blank"
			rel="noopener noreferrer"
			aria-label="Saiba mais sobre WCAG 2.2 (abre em nova aba)"
			class="inline-flex items-center gap-1.5 text-emerald-400 hover:text-emerald-300 underline underline-offset-4 focus:outline-none focus-visible:ring-2 focus-visible:ring-emerald-400 rounded"
		>
			Saiba mais sobre WCAG 2.2
			<ExternalLink class="w-4 h-4" aria-hidden="true" />
		</a>
	</footer>
</main>
