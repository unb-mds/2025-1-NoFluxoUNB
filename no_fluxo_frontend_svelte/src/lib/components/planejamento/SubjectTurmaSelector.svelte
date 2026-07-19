<script lang="ts">
	import { gradeStore } from '$lib/stores/grade.store.svelte';
	import { formatHorarioSigaa, compactarFaixasHorarias } from '$lib/utils/sigaa';
	import type { TurmaOferta } from '$lib/services/turmas.service';
	import { Check, Users, CalendarClock, Ban } from 'lucide-svelte';

	// Horário legível: "Seg 8h-9h50 · Qua 8h-9h50", ou aviso quando não há grade fixa.
	function horarioLegivel(horario: string | null): string {
		const linhas = formatHorarioSigaa(horario ?? '');
		if (linhas.length === 0) return 'Horário a definir';
		return linhas.map((l) => `${l.dia} ${compactarFaixasHorarias(l.faixas)}`).join(' · ');
	}

	function vagasBadge(t: TurmaOferta): { texto: string; classe: string } | null {
		if (t.vagas_sobrando == null) return null;
		return t.vagas_sobrando > 0
			? {
					texto: `${t.vagas_sobrando} vaga(s)`,
					classe: 'border-emerald-300/45 bg-emerald-500/18 text-emerald-100'
				}
			: { texto: 'Sem vagas', classe: 'border-red-300/40 bg-red-500/15 text-red-200' };
	}
</script>

<div class="space-y-3">
	{#each gradeStore.materias as materia (materia.codigo)}
		{@const cor = gradeStore.corDaMateria(materia.codigo)}
		{@const selecionada = gradeStore.turmaSelecionada(materia.codigo)}
		<section class="rounded-2xl border border-white/10 bg-zinc-950/78 p-3 sm:p-4">
			<header class="mb-2.5 flex items-start gap-2.5 border-b border-white/10 pb-2.5">
				<span class="mt-1 h-2.5 w-2.5 shrink-0 rounded-full {cor.dot}"></span>
				<div class="min-w-0 flex-1">
					<p class="flex flex-wrap items-baseline gap-x-2">
						<span class="font-mono text-sm font-semibold text-white/90">{materia.codigo}</span>
						<span class="truncate text-xs text-white/60">{materia.nome}</span>
					</p>
					<p class="mt-0.5 text-[11px] text-white/40">
						{materia.creditos} créditos ·
						{#if selecionada}
							<span class="text-white/70">Turma {selecionada.turma.turma} selecionada</span>
						{:else if materia.turmas.length === 0}
							<span class="text-amber-300/80">Sem turma ofertada neste período</span>
						{:else}
							{materia.turmas.length} turma(s) disponível(is)
						{/if}
					</p>
				</div>
				{#if selecionada}
					<button
						type="button"
						onclick={() => gradeStore.removerTurma(materia.codigo)}
						class="shrink-0 rounded-full border border-white/15 bg-white/5 px-2.5 py-1 text-[11px] font-medium text-white/70 transition-colors hover:bg-white/10"
					>
						Remover
					</button>
				{/if}
			</header>

			{#if materia.turmas.length > 0}
				<div class="max-h-64 space-y-1.5 overflow-y-auto pr-0.5">
					{#each materia.turmas as tg (tg.turma.id_turmas)}
						{@const t = tg.turma}
						{@const isSel = selecionada?.turma.id_turmas === t.id_turmas}
						{@const conflitoCom = gradeStore.conflitaCom(materia.codigo, tg)}
						{@const bloqueada = !isSel && conflitoCom !== null}
						{@const vagas = vagasBadge(t)}
						<button
							type="button"
							disabled={bloqueada}
							onclick={() =>
								isSel
									? gradeStore.removerTurma(materia.codigo)
									: gradeStore.selecionarTurma(materia.codigo, t.id_turmas)}
							class="w-full rounded-xl border px-3 py-2 text-left transition-colors {isSel
								? `${cor.cell} ${cor.text}`
								: bloqueada
									? 'cursor-not-allowed border-white/5 bg-white/[0.02] opacity-55'
									: 'border-white/10 bg-black/25 hover:bg-white/5'}"
						>
							<div class="flex items-center justify-between gap-2">
								<span class="flex items-center gap-1.5 font-mono text-xs font-semibold">
									{#if isSel}<Check class="h-3.5 w-3.5" />{/if}
									Turma {t.turma}
								</span>
								<span class="flex items-center gap-1.5">
									{#if vagas}
										<span
											class="flex items-center gap-1 rounded-full border px-2 py-0.5 text-[10px] font-semibold {vagas.classe}"
										>
											<Users class="h-2.5 w-2.5" />{vagas.texto}
										</span>
									{/if}
								</span>
							</div>
							<p class="mt-1 flex items-center gap-1.5 text-[11px] text-white/55">
								<CalendarClock class="h-3 w-3 shrink-0" />
								{horarioLegivel(t.horario)}
							</p>
							<p class="mt-0.5 truncate text-[11px] text-white/45">
								{t.docente ?? 'Docente não informado'}{#if t.local} · {t.local}{/if}
							</p>
							{#if bloqueada}
								<p class="mt-1 flex items-center gap-1 text-[10px] font-medium text-red-300/85">
									<Ban class="h-3 w-3" /> Conflita com {conflitoCom}
								</p>
							{/if}
						</button>
					{/each}
				</div>
			{/if}
		</section>
	{/each}
</div>
