<script lang="ts">
	import { gradeStore } from '$lib/stores/grade.store.svelte';
	import SeguirVagaButton from '$lib/components/materia/SeguirVagaButton.svelte';
	import { vagaAssinaturasStore } from '$lib/stores/vaga-assinaturas.store.svelte';
	import { formatLocalCompacto, horarioLegivel } from '$lib/utils/sigaa';
	import type { TurmaComMask } from '$lib/utils/horario-slots';
	import type { TurmaOferta } from '$lib/services/turmas.service';
	import { Check, Users, CalendarClock, Ban, Sparkles } from 'lucide-svelte';

	/**
	 * Uma linha de turma, reutilizada pelo seletor do montador, pelo diálogo de
	 * troca e pela busca de turmas. Deriva o estado (selecionada / bloqueada por
	 * conflito) direto do `gradeStore` — inclusive para matéria que ainda não está
	 * no pool, caso em que tudo degrada para "livre e não selecionada".
	 *
	 * `interativa=false` rende o mesmo cartão sem clique: é o que a busca usa para
	 * quem está fora do rollout do montador, para não oferecer um botão morto.
	 */
	let {
		codigo,
		tg,
		onToggle,
		interativa = true
	}: {
		codigo: string;
		tg: TurmaComMask<TurmaOferta>;
		onToggle: () => void;
		interativa?: boolean;
	} = $props();

	const t = $derived(tg.turma);
	const isSel = $derived(interativa && gradeStore.turmaSelecionada(codigo)?.turma.id_turmas === t.id_turmas);
	const conflitoCom = $derived(interativa ? gradeStore.conflitaCom(codigo, tg) : null);
	const bloqueada = $derived(!isSel && conflitoCom !== null);
	const cor = $derived(gradeStore.corDaMateria(codigo));
	// Turma que atende (ao menos em parte) a preferência declarada de turno/professor.
	const combinaComPreferencia = $derived(interativa && gradeStore.bonusPreferencia(codigo, tg) > 0);
	// O SIGAA às vezes embute o horário colado na sala ("2M34(BSA N AT 09/41) ...").
	const local = $derived(formatLocalCompacto(t.local));


	const vagas = $derived.by(() => {
		if (t.vagas_sobrando == null) return null;
		return t.vagas_sobrando > 0
			? {
					texto: `${t.vagas_sobrando} vaga(s)`,
					classe: 'border-emerald-300/45 bg-emerald-500/18 text-emerald-100'
				}
			: { texto: 'Sem vagas', classe: 'border-red-300/40 bg-red-500/15 text-red-200' };
	});

</script>

{#snippet conteudo()}
		<div class="flex items-center justify-between gap-2">
			<span class="flex items-center gap-1.5 font-mono text-xs font-semibold">
				{#if isSel}<Check class="h-3.5 w-3.5" />{/if}
				Turma {t.turma}
				{#if combinaComPreferencia}
					<span
						title="Combina com sua preferência de horário/professor"
						class="inline-flex items-center rounded-full border border-sky-300/40 bg-sky-500/15 px-1.5 py-px text-sky-200"
					>
						<Sparkles class="h-2.5 w-2.5" />
					</span>
				{/if}
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
			{t.docente ?? 'Docente não informado'}{#if local} · {local}{/if}
		</p>
		{#if bloqueada}
			<p class="mt-1 flex items-center gap-1 text-[10px] font-medium text-red-300/85">
				<Ban class="h-3 w-3" /> Conflita com {conflitoCom}
			</p>
		{/if}
{/snippet}

<div
	class="relative w-full rounded-xl border transition-colors {isSel
		? `${cor.cell} ${cor.text}`
		: bloqueada
			? 'border-white/5 bg-white/[0.02] opacity-55'
			: 'border-white/10 bg-black/25' + (interativa ? ' hover:bg-white/5' : '')}"
>
	{#if interativa}
		<button
			type="button"
			disabled={bloqueada}
			onclick={onToggle}
			class="w-full px-3 py-2 text-left {bloqueada ? 'cursor-not-allowed' : ''}"
		>
			{@render conteudo()}
		</button>
	{:else}
		<div class="w-full px-3 py-2 text-left">{@render conteudo()}</div>
	{/if}

	{#if vagaAssinaturasStore.podeSeguir(t)}
		<div class="border-t border-white/10 px-3 py-1.5">
			<SeguirVagaButton turma={t} />
		</div>
	{/if}
</div>
