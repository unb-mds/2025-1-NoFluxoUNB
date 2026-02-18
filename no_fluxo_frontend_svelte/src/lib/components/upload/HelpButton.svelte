<script lang="ts">
	import { HelpCircle } from 'lucide-svelte';

	interface Props {
		onclick: () => void;
	}

	let { onclick }: Props = $props();
</script>

<button
	type="button"
	class="help-btn"
	{onclick}
>
	<HelpCircle class="h-4 w-4" />
	<span>Como obter seu histórico acadêmico?</span>
</button>

<style>
	@reference 'tailwindcss';

	.help-btn {
		@apply flex items-center gap-2 rounded-full px-5 py-2.5 text-sm font-medium text-white transition-all duration-200;
		background: linear-gradient(135deg, rgba(108, 99, 255, 0.3), rgba(233, 30, 99, 0.3));
		border: 1px solid rgba(255, 255, 255, 0.1);
	}

	.help-btn:hover {
		@apply scale-[1.03];
		background: linear-gradient(135deg, rgba(108, 99, 255, 0.5), rgba(233, 30, 99, 0.5));
		box-shadow: 0 4px 15px rgba(108, 99, 255, 0.2);
	}
</style>
