<script lang="ts">
	import type { IntegralizacaoResult } from '$lib/types/matriz';
	import { parseCurriculoCompleto } from '$lib/types/matriz';
	import { BookOpen, CheckCircle, Clock } from 'lucide-svelte';

	interface Props {
		/** Resultado do serviço de integralização (exigido vs realizado). */
		integralizacao: IntegralizacaoResult | null;
		/** Lista de matrizes para troca (curriculo_completo). */
		matrizes?: Array<{ curriculoCompleto: string }>;
		/** Matriz selecionada atual. */
		curriculoCompletoAtual?: string | null;
		/** Callback ao trocar de matriz. */
		onMatrizChange?: (curriculoCompleto: string) => void;
	}

	let { integralizacao, matrizes = [], curriculoCompletoAtual = null, onMatrizChange }: Props = $props();

	function formatCh(n: number): string {
		return n.toLocaleString('pt-BR') + 'h';
	}

	function parsed(curriculoCompleto: string) {
		const p = parseCurriculoCompleto(curriculoCompleto);
		return `${p.codigoCurso}/${p.versao} ${p.ano ? `- ${p.ano}` : ''}`;
	}
</script>

{#if integralizacao}
	<div class="rounded-xl border border-white/10 bg-black/40 p-4 backdrop-blur-md">
		<div class="mb-3 flex flex-wrap items-center justify-between gap-2">
			<div class="flex items-center gap-1.5 text-cyan-400">
				<BookOpen class="h-4 w-4" />
				<span class="text-xs font-semibold uppercase tracking-wider">Carga horária (SIGAA)</span>
			</div>
			{#if matrizes.length > 1 && onMatrizChange}
				<select
					class="rounded-lg border border-white/20 bg-white/5 px-2 py-1 text-xs text-white focus:border-cyan-500 focus:outline-none"
					value={curriculoCompletoAtual ?? integralizacao.curriculoCompleto}
					onchange={(e) => onMatrizChange((e.target as HTMLSelectElement).value)}
				>
					{#each matrizes as m}
						<option value={m.curriculoCompleto}>{parsed(m.curriculoCompleto)}</option>
					{/each}
				</select>
			{/if}
		</div>

		<div class="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
			<div>
				<p class="text-white/50">Obrigatória</p>
				<p class="font-semibold text-white">
					{formatCh(integralizacao.realizado.chObrigatoria)}
					<span class="text-white/50"> / {formatCh(integralizacao.exigido.chObrigatoria)}</span>
				</p>
				{#if integralizacao.faltam.chObrigatoria > 0}
					<p class="flex items-center gap-1 text-amber-400">
						<Clock class="h-3 w-3" />
						Faltam {formatCh(integralizacao.faltam.chObrigatoria)}
					</p>
				{:else if integralizacao.exigido.chObrigatoria > 0}
					<p class="flex items-center gap-1 text-green-400">
						<CheckCircle class="h-3 w-3" />
						Completo
					</p>
				{/if}
			</div>
			<div>
				<p class="text-white/50">Optativa</p>
				<p class="font-semibold text-white">
					{formatCh(integralizacao.realizado.chOptativa)}
					<span class="text-white/50"> / {formatCh(integralizacao.exigido.chOptativa)}</span>
				</p>
				{#if integralizacao.faltam.chOptativa > 0}
					<p class="flex items-center gap-1 text-amber-400">
						<Clock class="h-3 w-3" />
						Faltam {formatCh(integralizacao.faltam.chOptativa)}
					</p>
				{:else if integralizacao.exigido.chOptativa > 0}
					<p class="flex items-center gap-1 text-green-400">
						<CheckCircle class="h-3 w-3" />
						Completo
					</p>
				{/if}
			</div>
			<div>
				<p class="text-white/50">Complementar</p>
				<p class="font-semibold text-white">
					{formatCh(integralizacao.realizado.chComplementar)}
					<span class="text-white/50"> / {formatCh(integralizacao.exigido.chComplementar)}</span>
				</p>
				{#if integralizacao.faltam.chComplementar > 0}
					<p class="flex items-center gap-1 text-amber-400">
						<Clock class="h-3 w-3" />
						Faltam {formatCh(integralizacao.faltam.chComplementar)}
					</p>
				{/if}
			</div>
			<div>
				<p class="text-white/50">Total</p>
				<p class="font-semibold text-white">
					{formatCh(integralizacao.realizado.chTotal)}
					<span class="text-white/50"> / {formatCh(integralizacao.exigido.chTotal)}</span>
				</p>
				{#if integralizacao.faltam.chTotal > 0}
					<p class="flex items-center gap-1 text-amber-400">
						<Clock class="h-3 w-3" />
						Faltam {formatCh(integralizacao.faltam.chTotal)}
					</p>
				{:else if integralizacao.exigido.chTotal > 0}
					<p class="flex items-center gap-1 text-green-400">
						<CheckCircle class="h-3 w-3" />
						Integralizado
					</p>
				{/if}
			</div>
		</div>
		<p class="mt-2 text-xs text-white/50">
			Valores oficiais da matriz (não calculados manualmente). Realizado = soma das disciplinas concluídas.
		</p>
	</div>
{/if}
