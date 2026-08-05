<script lang="ts">
	import { gradeStore } from '$lib/stores/grade.store.svelte';
	import type { Turno } from '$lib/utils/horario-slots';
	import TurmaOption from './TurmaOption.svelte';
	import { TriangleAlert, Star, Trash2, Info, SlidersHorizontal, X } from 'lucide-svelte';

	// Alterna a turma de uma matéria: clicar na já selecionada remove; senão seleciona.
	function toggle(codigo: string, idTurma: number) {
		if (gradeStore.turmaSelecionada(codigo)?.turma.id_turmas === idTurma) {
			gradeStore.removerTurma(codigo);
		} else {
			gradeStore.selecionarTurma(codigo, idTurma);
		}
	}

	// Painel de preferências aberto por matéria — fica fechado por padrão para não
	// poluir a lista de quem só quer escolher a turma na mão.
	let painelAberto = $state<string | null>(null);

	const TURNOS: ReadonlyArray<[Turno, string]> = [
		['M', 'Manhã'],
		['T', 'Tarde'],
		['N', 'Noite']
	];

	/** Resumo curto da preferência, para o rótulo do botão quando está fechado. */
	function resumoPreferencia(codigo: string): string {
		const p = gradeStore.preferenciaDe(codigo);
		const partes: string[] = [];
		if (p.turnos.length > 0) {
			partes.push(TURNOS.filter(([t]) => p.turnos.includes(t)).map(([, l]) => l).join('/'));
		}
		if (p.docente) partes.push(p.docente);
		return partes.join(' · ');
	}
</script>

<div class="space-y-3">
	{#each gradeStore.pool as materia (materia.codigo)}
		{@const cor = gradeStore.corDaMateria(materia.codigo)}
		{@const selecionada = gradeStore.turmaSelecionada(materia.codigo)}
		{@const prioritaria = gradeStore.isPrioritaria(materia.codigo)}
		<!-- Matéria que mudou de código: as turmas vêm todas do substituto, então basta a 1ª. -->
		{@const codigoOfertado = materia.turmas[0]?.codigoOfertado}
		<section
			class="rounded-2xl border border-white/10 bg-zinc-950/78 p-3"
			role="group"
			onmouseenter={() => gradeStore.setHover(materia.codigo)}
			onmouseleave={() => gradeStore.setHover(null)}
		>
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
					{#if codigoOfertado}
					<p class="mt-1 flex items-start gap-1 text-[10px] font-medium text-sky-300/90">
						<Info class="mt-px h-3 w-3 shrink-0" />
						<span>
							Ofertada como <span class="font-mono font-semibold">{codigoOfertado}</span> — é
							nesse código que você se matricula
						</span>
					</p>
				{/if}
				{#if materia.avisoPreRequisito}
						<p class="mt-1 flex items-start gap-1 text-[10px] font-medium text-amber-300/90">
							<TriangleAlert class="mt-px h-3 w-3 shrink-0" />
							<span>Pré-requisito pendente: {materia.avisoPreRequisito}</span>
						</p>
					{/if}
				</div>
				<div class="flex shrink-0 items-center gap-0.5">
					<button
						type="button"
						onclick={() => gradeStore.togglePrioridade(materia.codigo)}
						title={prioritaria ? 'Prioritária ao rearranjar — clique p/ remover' : 'Priorizar ao rearranjar'}
						aria-pressed={prioritaria}
						class="touch-manipulation rounded-lg p-1.5 transition-colors {prioritaria ? 'text-amber-300 hover:bg-amber-400/10' : 'text-white/30 hover:bg-white/10 hover:text-white/60'}"
					>
						<Star class="h-4 w-4 {prioritaria ? 'fill-current' : ''}" />
					</button>
					<button
						type="button"
						onclick={() => gradeStore.removerMateriaDoPool(materia.codigo)}
						title="Remover matéria da lista"
						aria-label="Remover {materia.codigo} da lista"
						class="touch-manipulation rounded-lg p-1.5 text-white/30 transition-colors hover:bg-red-500/15 hover:text-red-300"
					>
						<Trash2 class="h-4 w-4" />
					</button>
				</div>
			</header>

			{#if materia.turmas.length > 0}
				{@const pref = gradeStore.preferenciaDe(materia.codigo)}
				{@const temPref = gradeStore.temPreferencia(materia.codigo)}
				{@const docentes = gradeStore.docentesDe(materia.codigo)}
				{@const aberto = painelAberto === materia.codigo}

				<!-- Preferência de turno/professor: o Rearranjar tenta atender, mas cede
				     para não deixar a matéria de fora. -->
				<div class="mb-2">
					<button
						type="button"
						onclick={() => (painelAberto = aberto ? null : materia.codigo)}
						aria-expanded={aberto}
						class="inline-flex max-w-full touch-manipulation items-center gap-1.5 rounded-full border px-2.5 py-1 text-[10px] font-medium transition-colors {temPref
							? 'border-sky-300/45 bg-sky-500/15 text-sky-100 hover:bg-sky-500/25'
							: 'border-white/10 bg-white/5 text-white/50 hover:bg-white/10'}"
					>
						<SlidersHorizontal class="h-3 w-3 shrink-0" />
						{#if temPref}
							<span class="truncate">Prefiro: {resumoPreferencia(materia.codigo)}</span>
						{:else}
							Preferência de horário/professor
						{/if}
					</button>

					{#if aberto}
						<div class="mt-2 space-y-2 rounded-xl border border-white/10 bg-black/30 p-2.5">
							<div class="flex flex-wrap items-center gap-1.5">
								<span class="text-[10px] font-medium uppercase tracking-wide text-white/35">Turno</span>
								{#each TURNOS as [t, label] (t)}
									{@const ativo = pref.turnos.includes(t)}
									<button
										type="button"
										onclick={() => gradeStore.togglePreferenciaTurno(materia.codigo, t)}
										aria-pressed={ativo}
										class="touch-manipulation rounded-full border px-2 py-1 text-[10px] font-medium transition-colors {ativo
											? 'border-sky-300/45 bg-sky-500/20 text-sky-100'
											: 'border-white/10 bg-white/5 text-white/45 hover:bg-white/10'}"
									>
										{label}
									</button>
								{/each}
							</div>

							{#if docentes.length > 0}
								<label class="flex items-center gap-2">
									<span class="text-[10px] font-medium uppercase tracking-wide text-white/35">Prof.</span>
									<select
										value={pref.docente ?? ''}
										onchange={(e) =>
											gradeStore.setPreferenciaDocente(
												materia.codigo,
												(e.currentTarget as HTMLSelectElement).value || null
											)}
										class="min-w-0 flex-1 rounded-lg border border-white/10 bg-zinc-900 px-2 py-1 text-[11px] text-white/80 focus:outline-none focus:ring-1 focus:ring-sky-400/50"
									>
										<option value="">Tanto faz</option>
										{#each docentes as d (d)}
											<option value={d}>{d}</option>
										{/each}
									</select>
								</label>
							{:else}
								<p class="text-[10px] text-white/30">Nenhuma turma tem docente informado.</p>
							{/if}

							<div class="flex items-center justify-between gap-2 pt-0.5">
								<p class="text-[10px] leading-snug text-white/35">
									O Rearranjar tenta atender, mas cede se for a única forma de a matéria caber.
								</p>
								{#if temPref}
									<button
										type="button"
										onclick={() => gradeStore.limparPreferencia(materia.codigo)}
										class="inline-flex shrink-0 touch-manipulation items-center gap-1 rounded-full border border-white/10 bg-white/5 px-2 py-1 text-[10px] text-white/50 transition-colors hover:bg-white/10"
									>
										<X class="h-3 w-3" /> Limpar
									</button>
								{/if}
							</div>
						</div>
					{/if}
				</div>

				<div class="max-h-60 space-y-1.5 overflow-y-auto pr-0.5">
					{#each materia.turmas as tg (tg.turma.id_turmas)}
						<TurmaOption
							codigo={materia.codigo}
							{tg}
							onToggle={() => toggle(materia.codigo, tg.turma.id_turmas)}
						/>
					{/each}
				</div>
			{/if}
		</section>
	{/each}
</div>
