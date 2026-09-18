<script lang="ts">
	import type { HTMLInputAttributes, HTMLInputTypeAttribute } from "svelte/elements";
	import { cn, type WithElementRef } from "$lib/utils.js";

	type InputType = Exclude<HTMLInputTypeAttribute, "file">;

	type Props = WithElementRef<
		Omit<HTMLInputAttributes, "type"> &
			({ type: "file"; files?: FileList } | { type?: InputType; files?: undefined })
	>;

	let {
		ref = $bindable(null),
		value = $bindable(),
		type,
		files = $bindable(),
		class: className,
		"data-slot": dataSlot = "input",
		...restProps
	}: Props = $props();
</script>

{#if type === "file"}
	<input
		bind:this={ref}
		data-slot={dataSlot}
		class={cn(
			"selection:bg-primary selection:text-primary-foreground border-input bg-secondary/40 placeholder:text-muted-foreground flex h-11 w-full min-w-0 rounded-lg border px-3.5 py-2 text-[15px] font-medium shadow-none transition-[color,box-shadow,border-color] outline-none md:text-sm disabled:cursor-not-allowed disabled:opacity-45",
			"focus-visible:border-ring focus-visible:ring-ring/35 focus-visible:ring-[3px]",
			"aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive",
			className
		)}
		type="file"
		bind:files
		bind:value
		{...restProps}
	/>
{:else}
	<input
		bind:this={ref}
		data-slot={dataSlot}
		class={cn(
			"border-input bg-background selection:bg-primary selection:text-primary-foreground flex h-11 w-full min-w-0 rounded-lg border px-3.5 py-2 text-[15px] shadow-none transition-[color,box-shadow,border-color] outline-none disabled:cursor-not-allowed disabled:opacity-45 md:text-sm",
			"focus-visible:border-ring focus-visible:ring-ring/35 focus-visible:ring-[3px]",
			"aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive",
			className
		)}
		{type}
		bind:value
		{...restProps}
	/>
{/if}
