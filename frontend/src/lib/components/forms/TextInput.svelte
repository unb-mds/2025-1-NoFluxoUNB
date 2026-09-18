<script lang="ts">
	import { cn } from '$lib/utils';
	import { AlertCircle } from 'lucide-svelte';

	interface Props {
		name: string;
		label?: string;
		placeholder?: string;
		type?: 'text' | 'email' | 'password' | 'number' | 'tel' | 'url';
		value?: string;
		error?: string;
		disabled?: boolean;
		required?: boolean;
		autocomplete?: HTMLInputElement['autocomplete'];
		class?: string;
		onchange?: (value: string) => void;
		oninput?: (value: string) => void;
	}

	let {
		name,
		label,
		placeholder = '',
		type = 'text',
		value = $bindable(''),
		error,
		disabled = false,
		required = false,
		autocomplete,
		class: className = '',
		onchange,
		oninput
	}: Props = $props();

	let focused = $state(false);

	function handleInput(e: Event) {
		const target = e.target as HTMLInputElement;
		value = target.value;
		oninput?.(value);
	}

	function handleChange(e: Event) {
		const target = e.target as HTMLInputElement;
		value = target.value;
		onchange?.(value);
	}
</script>

<div class={cn('text-input-wrapper', className)}>
	{#if label}
		<label for={name} class="block text-sm font-medium text-white/80 mb-1.5">
			{label}
			{#if required}
				<span class="text-pink-500">*</span>
			{/if}
		</label>
	{/if}

	<div class="relative">
		<input
			{type}
			{name}
			id={name}
			{placeholder}
			{value}
			{disabled}
			{required}
			{autocomplete}
			class={cn(
				'w-full px-4 py-3 rounded-xl',
				'bg-white/10 border border-white/20',
				'text-white placeholder-white/40',
				'focus:outline-none focus:ring-2 focus:ring-purple-500/50',
				'focus:border-purple-500',
				'transition-all duration-200',
				'disabled:opacity-50 disabled:cursor-not-allowed',
				error && 'border-red-500 focus:ring-red-500/50'
			)}
			oninput={handleInput}
			onchange={handleChange}
			onfocus={() => (focused = true)}
			onblur={() => (focused = false)}
		/>

		{#if error}
			<div class="absolute right-3 top-1/2 -translate-y-1/2">
				<AlertCircle size={20} class="text-red-500" />
			</div>
		{/if}
	</div>

	{#if error}
		<p class="mt-1.5 text-sm text-red-400 flex items-center gap-1">
			{error}
		</p>
	{/if}
</div>
