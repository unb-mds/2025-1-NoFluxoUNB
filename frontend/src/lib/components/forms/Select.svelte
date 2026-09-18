<script lang="ts">
	import { cn } from '$lib/utils';
	import { ChevronDown } from 'lucide-svelte';

	interface Option {
		value: string;
		label: string;
		disabled?: boolean;
	}

	interface Props {
		name: string;
		label?: string;
		placeholder?: string;
		options: Option[];
		value?: string;
		error?: string;
		disabled?: boolean;
		required?: boolean;
		class?: string;
		onchange?: (value: string) => void;
	}

	let {
		name,
		label,
		placeholder = 'Selecione uma opção',
		options,
		value = $bindable(''),
		error,
		disabled = false,
		required = false,
		class: className = '',
		onchange
	}: Props = $props();

	function handleChange(e: Event) {
		const target = e.target as HTMLSelectElement;
		value = target.value;
		onchange?.(value);
	}
</script>

<div class={cn('select-wrapper', className)}>
	{#if label}
		<label for={name} class="block text-sm font-medium text-white/80 mb-1.5">
			{label}
			{#if required}
				<span class="text-pink-500">*</span>
			{/if}
		</label>
	{/if}

	<div class="relative">
		<select
			{name}
			id={name}
			{value}
			{disabled}
			{required}
			class={cn(
				'w-full px-4 py-3 pr-10 rounded-xl appearance-none',
				'bg-white/10 border border-white/20',
				'text-white',
				'focus:outline-none focus:ring-2 focus:ring-purple-500/50',
				'focus:border-purple-500',
				'transition-all duration-200',
				'disabled:opacity-50 disabled:cursor-not-allowed',
				error && 'border-red-500 focus:ring-red-500/50',
				!value && 'text-white/40'
			)}
			onchange={handleChange}
		>
			<option value="" disabled>{placeholder}</option>
			{#each options as option}
				<option value={option.value} disabled={option.disabled} class="bg-gray-900 text-white">
					{option.label}
				</option>
			{/each}
		</select>

		<div class="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
			<ChevronDown size={20} class="text-white/60" />
		</div>
	</div>

	{#if error}
		<p class="mt-1.5 text-sm text-red-400">{error}</p>
	{/if}
</div>
