<script lang="ts">
	import type { IntegralizacaoResult } from '$lib/types/matriz';
	import { parseCurriculoCompleto } from '$lib/types/matriz';
	import CargaHorariaDashboard from './CargaHorariaDashboard.svelte';

	interface Props {
		integralizacao: IntegralizacaoResult | null;
		matrizes?: Array<{ curriculoCompleto: string }>;
		curriculoCompletoAtual?: string | null;
		onMatrizChange?: (curriculoCompleto: string) => void;
	}

	let { integralizacao, matrizes = [], curriculoCompletoAtual = null, onMatrizChange }: Props = $props();

	function parsed(curriculoCompleto: string) {
		const p = parseCurriculoCompleto(curriculoCompleto);
		return `${p.codigoCurso}/${p.versao} ${p.ano ? `- ${p.ano}` : ''}`;
	}
</script>

{#if integralizacao}
	<div class="min-w-0 rounded-xl border border-white/10 bg-black/40 p-3 backdrop-blur-md sm:p-4">
		{#if matrizes.length > 1 && onMatrizChange}
			<div class="mb-3 flex justify-end">
				<select
					class="rounded-lg border border-white/20 bg-white/5 px-2 py-1.5 text-xs text-white focus:border-cyan-500 focus:outline-none"
					value={curriculoCompletoAtual ?? integralizacao.curriculoCompleto}
					onchange={(e) => onMatrizChange((e.target as HTMLSelectElement).value)}
				>
					{#each matrizes as m}
						<option value={m.curriculoCompleto}>{parsed(m.curriculoCompleto)}</option>
					{/each}
				</select>
			</div>
		{/if}
		<CargaHorariaDashboard dadosUser={integralizacao} />
	</div>
{/if}
