<script lang="ts">
	import { gradeStore } from '$lib/stores/grade.store.svelte';
	import { vagaAssinaturasStore } from '$lib/stores/vaga-assinaturas.store.svelte';
	import { formatHorarioSigaa, compactarFaixasHorarias } from '$lib/utils/sigaa';
	import type { TurmaComMask } from '$lib/utils/horario-slots';
	import type { TurmaOferta } from '$lib/services/turmas.service';
	import { Check, Users, CalendarClock, Ban, Bell, BellOff, Loader2 } from 'lucide-svelte';

	// Uma linha de turma reutilizada pelo seletor e pelo diálogo de troca. Deriva o
	// estado (selecionada / bloqueada por conflito) direto do gradeStore.
	let {
		codigo,
		tg,
		onToggle
	}: { codigo: string; tg: TurmaComMask<TurmaOferta>; onToggle: () => void } = $props();

	const t = $derived(tg.turma);
	const isSel = $derived(gradeStore.turmaSelecionada(codigo)?.turma.id_turmas === t.id_turmas);
	const conflitoCom = $derived(gradeStore.conflitaCom(codigo, tg));
	const bloqueada = $derived(!isSel && conflitoCom !== null);
	const cor = $derived(gradeStore.corDaMateria(codigo));

	function horarioLegivel(horario: string | null): string {
		const linhas = formatHorarioSigaa(horario ?? '');
		if (linhas.length === 0) return 'Horário a definir';
		return linhas.map((l) => `${l.dia} ${compactarFaixasHorarias(l.faixas)}`).join(' · ');
	}

	const vagas = $derived.by(() => {
		if (t.vagas_sobrando == null) return null;
		return t.vagas_sobrando > 0
			? {
					texto: `${t.vagas_sobrando} vaga(s)`,
					classe: 'border-emerald-300/45 bg-emerald-500/18 text-emerald-100'
				}
			: { texto: 'Sem vagas', classe: 'border-red-300/40 bg-red-500/15 text-red-200' };
	});

	// "Seguir vaga": só faz sentido para turma lotada e com assinaturas carregadas.
	const mostrarSeguir = $derived(
		t.vagas_sobrando != null && t.vagas_sobrando <= 0 && vagaAssinaturasStore.carregado
	);
	const seguindo = $derived(
		mostrarSeguir && vagaAssinaturasStore.isSeguindo(t.id_materia, t.turma, t.ano_periodo)
	);
	const seguirBusy = $derived(
		mostrarSeguir && vagaAssinaturasStore.isBusy(t.id_materia, t.turma, t.ano_periodo)
	);
</script>

<div
	class="relative w-full rounded-xl border transition-colors {isSel
		? `${cor.cell} ${cor.text}`
		: bloqueada
			? 'border-white/5 bg-white/[0.02] opacity-55'
			: 'border-white/10 bg-black/25 hover:bg-white/5'}"
>
	<button
		type="button"
		disabled={bloqueada}
		onclick={onToggle}
		class="w-full px-3 py-2 text-left {bloqueada ? 'cursor-not-allowed' : ''}"
	>
		<div class="flex items-center justify-between gap-2">
			<span class="flex items-center gap-1.5 font-mono text-xs font-semibold">
				{#if isSel}<Check class="h-3.5 w-3.5" />{/if}
				Turma {t.turma}
			</span>
			{#if vagas}
				<span
					class="flex items-center gap-1 rounded-full border px-2 py-0.5 text-[10px] font-semibold {vagas.classe}"
				>
					<Users class="h-2.5 w-2.5" />{vagas.texto}
				</span>
			{/if}
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

	{#if mostrarSeguir}
		<div class="border-t border-white/10 px-3 py-1.5">
			<button
				type="button"
				disabled={seguirBusy}
				onclick={() => vagaAssinaturasStore.toggle(t.id_materia, t.turma, t.ano_periodo)}
				class="inline-flex items-center gap-1.5 rounded-full border px-2 py-0.5 text-[10px] font-medium transition-colors disabled:opacity-50 {seguindo
					? 'border-purple-300/45 bg-purple-500/18 text-purple-100 hover:bg-purple-500/25'
					: 'border-white/15 bg-white/5 text-white/60 hover:bg-white/10'}"
			>
				{#if seguirBusy}
					<Loader2 class="h-3 w-3 animate-spin" />
				{:else if seguindo}
					<Bell class="h-3 w-3" />
				{:else}
					<BellOff class="h-3 w-3" />
				{/if}
				{seguindo ? 'Seguindo — aviso quando abrir vaga' : 'Avisar quando abrir vaga'}
			</button>
		</div>
	{/if}
</div>
