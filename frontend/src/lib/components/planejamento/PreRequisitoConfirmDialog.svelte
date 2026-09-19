<script lang="ts">
	import * as Dialog from '$lib/components/ui/dialog';
	import { TriangleAlert } from 'lucide-svelte';
	import { nomeDoCodigo, type PendenciaPreRequisito } from '$lib/services/grade-pool.service';

	/**
	 * Aviso de pré-requisito pendente na hora de adicionar matéria.
	 *
	 * Avisa e deixa passar de propósito: pré-requisito aqui é advisory (mesma regra
	 * de `calcularRequisitos`), e quem está cursando o pré-requisito neste semestre
	 * tem motivo legítimo para colocar a matéria na grade mesmo assim.
	 *
	 * Aceita várias pendências porque a adição em lote (`[MONTAR_GRADE|A,B,C]`)
	 * viraria uma fila de pop-ups — o aluno vê tudo de uma vez e decide uma vez só.
	 */
	let {
		pendencias,
		onConfirmar,
		onCancelar
	}: {
		/** Pendências a confirmar; lista vazia mantém o diálogo fechado. */
		pendencias: PendenciaPreRequisito[];
		onConfirmar: () => void;
		onCancelar: () => void;
	} = $props();

	const aberto = $derived(pendencias.length > 0);

	// Nome só entra quando é diferente do código — repetir "MAT0025 · MAT0025"
	// (caso de pré-requisito que não está na matriz) só faz ruído.
	const grupos = $derived(
		pendencias.map((p) => ({
			...p,
			itens: p.faltantes.map((parte) => {
				const nome = nomeDoCodigo(parte);
				return { parte, nome: nome && nome.toUpperCase() !== parte.toUpperCase() ? nome : null };
			})
		}))
	);

	/** O caso de uma matéria só é o comum (busca e chat) e mantém o texto direto. */
	const unica = $derived(grupos.length === 1 ? grupos[0] : null);
</script>

{#snippet listaFaltantes(itens: Array<{ parte: string; nome: string | null }>)}
	{#if itens.length > 0}
		<ul class="space-y-1.5">
			{#each itens as f (f.parte)}
				<li class="flex items-start gap-2 text-[13px]">
					<span class="mt-1.5 h-1 w-1 shrink-0 rounded-full bg-amber-300/80"></span>
					<span class="font-mono font-semibold text-amber-200">{f.parte}</span>
					{#if f.nome}
						<span class="text-white/60">{f.nome}</span>
					{/if}
				</li>
			{/each}
		</ul>
	{:else}
		<p class="text-[13px] text-white/70">
			A matriz exige pré-requisitos que você ainda não concluiu.
		</p>
	{/if}
{/snippet}

<Dialog.Root
	open={aberto}
	onOpenChange={(v) => {
		if (!v) onCancelar();
	}}
>
	<Dialog.Content
		class="border-white/10 bg-zinc-950 text-white sm:max-w-md"
		showCloseButton={false}
	>
		<Dialog.Header>
			<Dialog.Title class="flex items-center gap-2 text-base text-white">
				<TriangleAlert class="h-5 w-5 shrink-0 text-amber-300" />
				<span>Faltam pré-requisitos</span>
			</Dialog.Title>
			<Dialog.Description class="text-sm text-white/60">
				{#if unica}
					Para cursar <span class="font-mono font-semibold text-white/85">{unica.codigo}</span>
					— {unica.nome} — você precisa antes de:
				{:else if grupos.length > 1}
					{grupos.length} das matérias que você quer adicionar pedem outras que você ainda não concluiu:
				{/if}
			</Dialog.Description>
		</Dialog.Header>

		{#if unica}
			<div class="rounded-xl border border-amber-400/20 bg-amber-400/5 p-3">
				{@render listaFaltantes(unica.itens)}
			</div>

			{#if unica.expressaoOriginal}
				<p class="text-[11px] text-white/45">
					Regra da matriz:
					<span class="font-mono text-white/70">{unica.expressaoOriginal}</span>
				</p>
			{/if}
		{:else if grupos.length > 1}
			<div class="max-h-[45vh] space-y-2 overflow-y-auto pr-1">
				{#each grupos as g (g.codigo)}
					<div class="rounded-xl border border-amber-400/20 bg-amber-400/5 p-3">
						<p class="mb-1.5 text-[13px]">
							<span class="font-mono font-semibold text-white/85">{g.codigo}</span>
							<span class="text-white/60"> — {g.nome}</span>
						</p>
						{@render listaFaltantes(g.itens)}
						{#if g.expressaoOriginal}
							<p class="mt-1.5 text-[11px] text-white/45">
								Regra da matriz:
								<span class="font-mono text-white/70">{g.expressaoOriginal}</span>
							</p>
						{/if}
					</div>
				{/each}
			</div>
		{/if}

		{#if aberto}
			<p class="text-[13px] text-white/60">
				Se você está cursando essas matérias agora, pode seguir sem problema. Se não, o SIGAA pode
				recusar sua matrícula.
			</p>
		{/if}

		<Dialog.Footer>
			<button
				type="button"
				onclick={onCancelar}
				class="rounded-full border border-white/15 px-4 py-2 text-xs font-semibold text-white/70 transition-colors hover:bg-white/5 focus-visible:ring-2 focus-visible:ring-white/40 focus-visible:outline-none"
			>
				Cancelar
			</button>
			<button
				type="button"
				onclick={onConfirmar}
				class="rounded-full bg-amber-400 px-4 py-2 text-xs font-semibold text-zinc-950 transition-colors hover:bg-amber-300 focus-visible:ring-2 focus-visible:ring-amber-200 focus-visible:ring-offset-2 focus-visible:ring-offset-zinc-950 focus-visible:outline-none"
			>
				{grupos.length > 1 ? 'Adicionar todas mesmo assim' : 'Adicionar mesmo assim'}
			</button>
		</Dialog.Footer>
	</Dialog.Content>
</Dialog.Root>
