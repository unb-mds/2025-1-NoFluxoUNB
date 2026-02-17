<script lang="ts">
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import { Bot } from 'lucide-svelte';
</script>

<PageMeta
	title="Assistente IA"
	description="Converse com o assistente inteligente do NoFluxo para tirar dúvidas sobre seu curso"
/>

<AnimatedBackground />

<div class="relative z-10 container mx-auto max-w-4xl px-4 py-8">
	<div class="mb-6">
		<h1 class="text-2xl font-bold text-white">Assistente IA</h1>
		<p class="text-gray-300">Tire suas dúvidas sobre disciplinas, pré-requisitos e mais.</p>
	</div>

	<div class="glass-light rounded-2xl p-8 text-center">
		<div class="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-pink-500/20">
			<Bot class="h-8 w-8 text-pink-400" />
		</div>
		<h2 class="mb-2 text-xl font-semibold text-white">Em breve</h2>
		<p class="text-gray-400">
			O assistente IA está em desenvolvimento. Em breve você poderá conversar sobre seu fluxograma aqui.
		</p>
	</div>
</div>
