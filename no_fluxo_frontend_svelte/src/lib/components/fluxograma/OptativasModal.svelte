<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { X, Search, Plus, Check } from 'lucide-svelte';

	interface Props {
		optativas: MateriaModel[];
		onclose?: () => void;
	}

	let { optativas, onclose }: Props = $props();

	const store = fluxogramaStore;

	let searchQuery = $state('');
	let selectedSemester = $state(1);
	let selectedCodes = $state<Set<string>>(new Set());

	let filtered = $derived.by(() => {
		if (!searchQuery.trim()) return optativas;
		const q = searchQuery.toLowerCase();
		return optativas.filter(
			(m) =>
				m.nomeMateria.toLowerCase().includes(q) ||
				m.codigoMateria.toLowerCase().includes(q)
		);
	});

	// Check if an optativa is already added
	function isAlreadyAdded(code: string): boolean {
		return store.optativasAdicionadas.some(
			(o) => o.materia.codigoMateria === code
		);
	}

	function toggleSelection(code: string) {
		const next = new Set(selectedCodes);
		if (next.has(code)) {
			next.delete(code);
		} else {
			next.add(code);
		}
		selectedCodes = next;
	}

	function handleConfirm() {
		for (const code of selectedCodes) {
			const materia = optativas.find((m) => m.codigoMateria === code);
			if (materia) {
				store.addOptativa(materia, selectedSemester);
			}
		}
		selectedCodes = new Set();
		onclose?.();
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onclose?.();
	}

	function handleBackdropClick(e: MouseEvent) {
		if (e.target === e.currentTarget) onclose?.();
	}
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm"
	onclick={handleBackdropClick}
>
	<div
		class="relative max-h-[85vh] w-full max-w-lg overflow-hidden rounded-2xl border border-white/10 bg-gray-900/95 shadow-2xl backdrop-blur-xl"
		role="dialog"
		aria-modal="true"
		aria-label="Adicionar matérias optativas"
	>
		<!-- Header -->
		<div class="flex items-center justify-between border-b border-white/10 px-6 py-4">
			<h2 class="text-lg font-bold text-white">Adicionar Optativas</h2>
			<button
				onclick={onclose}
				class="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-white/70 transition-colors hover:bg-white/20 hover:text-white"
				aria-label="Fechar"
			>
				<X class="h-4 w-4" />
			</button>
		</div>

		<!-- Search + Semester selector -->
		<div class="space-y-3 border-b border-white/10 px-6 py-3">
			<div class="relative">
				<Search class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
				<input
					type="text"
					bind:value={searchQuery}
					placeholder="Buscar optativa..."
					class="w-full rounded-lg border border-white/10 bg-white/5 py-2 pl-10 pr-4 text-sm text-white placeholder-white/40 outline-none focus:border-purple-500/50 focus:ring-1 focus:ring-purple-500/30"
				/>
			</div>
			<div class="flex items-center gap-3">
				<label for="semester-select" class="text-xs font-medium text-white/60">Semestre:</label>
				<select
					id="semester-select"
					bind:value={selectedSemester}
					class="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-sm text-white outline-none focus:border-purple-500/50"
				>
					{#each Array.from({ length: 10 }, (_, i) => i + 1) as sem}
						<option value={sem} class="bg-gray-900 text-white">{sem}º semestre</option>
					{/each}
				</select>
			</div>
		</div>

		<!-- List -->
		<div class="max-h-[45vh] overflow-y-auto px-6 py-4">
			{#if filtered.length === 0}
				<p class="py-8 text-center text-sm text-white/50">
					{searchQuery ? 'Nenhuma optativa encontrada.' : 'Nenhuma matéria optativa disponível.'}
				</p>
			{:else}
				<div class="space-y-2">
					{#each filtered as materia (materia.idMateria)}
						{@const added = isAlreadyAdded(materia.codigoMateria)}
						{@const selected = selectedCodes.has(materia.codigoMateria)}
						<button
							onclick={() => !added && toggleSelection(materia.codigoMateria)}
							disabled={added}
							class="flex w-full items-center gap-3 rounded-lg border px-4 py-3 text-left transition-colors {added
								? 'border-white/5 bg-white/5 opacity-50 cursor-not-allowed'
								: selected
									? 'border-purple-500/50 bg-purple-500/10'
									: 'border-white/5 bg-white/5 hover:bg-white/10'}"
						>
							<div class="flex h-5 w-5 shrink-0 items-center justify-center rounded border {selected ? 'border-purple-400 bg-purple-500' : 'border-white/20 bg-white/5'}">
								{#if selected}
									<Check class="h-3 w-3 text-white" />
								{:else if added}
									<Check class="h-3 w-3 text-white/40" />
								{/if}
							</div>
							<div class="flex-1">
								<p class="text-sm font-medium text-white/90">{materia.nomeMateria}</p>
								<p class="text-xs text-white/50">{materia.codigoMateria}</p>
							</div>
							<span class="shrink-0 rounded-full bg-white/10 px-2 py-0.5 text-xs text-white/60">
								{materia.creditos} cr
							</span>
							{#if added}
								<span class="text-xs text-green-400">Adicionada</span>
							{/if}
						</button>
					{/each}
				</div>
			{/if}
		</div>

		<!-- Footer -->
		<div class="flex items-center justify-between border-t border-white/10 px-6 py-3">
			<span class="text-xs text-white/40">
				{filtered.length} matéria{filtered.length !== 1 ? 's' : ''}
				{#if selectedCodes.size > 0}
					 · {selectedCodes.size} selecionada{selectedCodes.size !== 1 ? 's' : ''}
				{/if}
			</span>
			<button
				onclick={handleConfirm}
				disabled={selectedCodes.size === 0}
				class="inline-flex items-center gap-1.5 rounded-lg px-4 py-2 text-sm font-medium transition-colors {selectedCodes.size > 0
					? 'bg-purple-600 text-white hover:bg-purple-500'
					: 'bg-white/5 text-white/30 cursor-not-allowed'}"
			>
				<Plus class="h-4 w-4" />
				Adicionar ({selectedCodes.size})
			</button>
		</div>
	</div>
</div>
