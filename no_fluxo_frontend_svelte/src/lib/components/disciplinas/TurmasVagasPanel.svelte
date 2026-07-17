<script lang="ts">
	import { createSupabaseBrowserClient } from '$lib/supabase/client';
	import { vagaNotificacaoService } from '$lib/services/vaga-notificacao.service';
	import type { VagaAssinatura } from '$lib/types/notificacao';
	import { Bell, BellOff, Loader2 } from 'lucide-svelte';

	interface Props {
		idMateria: number;
		codigoMateria?: string;
		nomeMateria?: string;
	}

	let { idMateria, codigoMateria, nomeMateria }: Props = $props();

	type TurmaRow = {
		id_turmas: number;
		turma: string;
		docente: string | null;
		horario: string | null;
		local: string | null;
		ano_periodo: string;
		vagas_ofertadas: number | null;
		vagas_ocupadas: number | null;
		vagas_sobrando: number | null;
	};

	const supabase = createSupabaseBrowserClient();

	let turmas = $state<TurmaRow[]>([]);
	let carregandoTurmas = $state(false);
	let erroTurmas = $state<string | null>(null);

	let assinaturas = $state<VagaAssinatura[]>([]);
	let carregandoAssinaturas = $state(false);

	let acaoEmAndamento = $state<string | null>(null);
	let erroAcao = $state<string | null>(null);

	let periodoAtual = $state<string | null>(null);

	function assinaturaKey(turma: string | null, anoPeriodo: string): string {
		return `${turma ?? '__toda__'}::${anoPeriodo}`;
	}

	function encontrarAssinatura(turma: string | null, anoPeriodo: string): VagaAssinatura | null {
		return (
			assinaturas.find(
				(a) =>
					a.ativa &&
					a.id_materia === idMateria &&
					(a.turma ?? null) === turma &&
					a.ano_periodo === anoPeriodo
			) ?? null
		);
	}

	async function carregarTurmas() {
		carregandoTurmas = true;
		erroTurmas = null;
		try {
			const { data: periodoData, error: periodoError } =
				await supabase.rpc('periodo_letivo_atual');
			if (periodoError) {
				erroTurmas = periodoError.message;
				turmas = [];
				return;
			}
			periodoAtual = periodoData as string;

			const { data, error } = await supabase
				.from('turmas')
				.select(
					'id_turmas, turma, docente, horario, local, ano_periodo, vagas_ofertadas, vagas_ocupadas, vagas_sobrando'
				)
				.eq('id_materia', idMateria)
				.eq('ano_periodo', periodoAtual)
				.order('turma');
			if (error) {
				erroTurmas = error.message;
				turmas = [];
				return;
			}
			turmas = (data as TurmaRow[] | null) ?? [];
		} catch (e: unknown) {
			erroTurmas = e instanceof Error ? e.message : 'Erro ao carregar turmas.';
			turmas = [];
		} finally {
			carregandoTurmas = false;
		}
	}

	async function carregarAssinaturas() {
		carregandoAssinaturas = true;
		try {
			assinaturas = await vagaNotificacaoService.listarMinhasAssinaturas();
		} catch {
			// Falha ao carregar assinaturas não deve travar a listagem de turmas.
			assinaturas = [];
		} finally {
			carregandoAssinaturas = false;
		}
	}

	async function alternarSeguir(turma: string | null, anoPeriodo: string) {
		const key = assinaturaKey(turma, anoPeriodo);
		acaoEmAndamento = key;
		erroAcao = null;
		try {
			const existente = encontrarAssinatura(turma, anoPeriodo);
			if (existente) {
				await vagaNotificacaoService.deixarDeSeguir(existente.id_assinatura);
			} else {
				await vagaNotificacaoService.seguirMateria(idMateria, turma, anoPeriodo);
			}
			await carregarAssinaturas();
		} catch (e: unknown) {
			erroAcao = e instanceof Error ? e.message : 'Erro ao atualizar acompanhamento.';
		} finally {
			acaoEmAndamento = null;
		}
	}

	$effect(() => {
		void idMateria;
		turmas = [];
		carregarTurmas();
		carregarAssinaturas();
	});
</script>

<section class="rounded-2xl border border-white/10 bg-zinc-950/78 p-4 sm:p-5">
	<div class="mb-3 flex flex-wrap items-center justify-between gap-2 border-b border-white/10 pb-2">
		<p class="text-xs font-semibold uppercase tracking-[0.12em] text-white/80">
			Turmas e vagas{#if codigoMateria} · <span class="font-mono text-purple-300">{codigoMateria}</span>{/if}
			{#if periodoAtual}
				<span class="ml-1 rounded-full border border-white/10 bg-white/5 px-2 py-0.5 text-[10px] normal-case tracking-normal text-white/50">
					{periodoAtual}
				</span>
			{/if}
		</p>
		{#if !carregandoTurmas && !erroTurmas && turmas.length > 0 && periodoAtual}
			<button
				type="button"
				disabled={acaoEmAndamento === assinaturaKey(null, periodoAtual)}
				onclick={() => alternarSeguir(null, periodoAtual!)}
				class="inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-medium transition-colors disabled:opacity-50 {encontrarAssinatura(
					null,
					periodoAtual
				)
					? 'border-purple-300/45 bg-purple-500/18 text-purple-100 hover:bg-purple-500/25'
					: 'border-white/15 bg-white/5 text-white/70 hover:bg-white/10'}"
			>
				{#if acaoEmAndamento === assinaturaKey(null, periodoAtual)}
					<Loader2 class="h-3 w-3 animate-spin" />
				{:else if encontrarAssinatura(null, periodoAtual)}
					<Bell class="h-3 w-3" />
				{:else}
					<BellOff class="h-3 w-3" />
				{/if}
				{encontrarAssinatura(null, periodoAtual) ? 'Seguindo toda a matéria' : 'Seguir toda a matéria'}
			</button>
		{/if}
	</div>

	{#if erroAcao}
		<p class="mb-2 text-xs text-red-300/85">{erroAcao}</p>
	{/if}

	{#if carregandoTurmas}
		<p class="flex items-center gap-2 text-xs text-white/55">
			<Loader2 class="h-3.5 w-3.5 animate-spin" /> Carregando turmas...
		</p>
	{:else if erroTurmas}
		<p class="text-xs text-red-300/85">{erroTurmas}</p>
	{:else if turmas.length === 0}
		<p class="text-xs text-white/45">
			Nenhuma turma cadastrada{#if nomeMateria} para {nomeMateria}{/if} no período {periodoAtual ??
				'atual'}.
		</p>
	{:else}
		<div class="space-y-2">
			{#each turmas as t (t.id_turmas)}
				{@const seguindo = encontrarAssinatura(t.turma, t.ano_periodo)}
				{@const key = assinaturaKey(t.turma, t.ano_periodo)}
				<div class="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-white/10 bg-black/25 px-3 py-2.5">
					<div class="min-w-0 flex-1">
						<div class="flex flex-wrap items-center gap-2">
							<span class="font-mono text-xs font-semibold text-purple-200">Turma {t.turma}</span>
							<span class="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 text-[10px] text-white/60">
								{t.ano_periodo}
							</span>
							{#if t.vagas_sobrando != null}
								<span
									class="rounded-full border px-2 py-0.5 text-[10px] font-semibold {t.vagas_sobrando > 0
										? 'border-emerald-300/45 bg-emerald-500/18 text-emerald-100'
										: 'border-red-300/40 bg-red-500/15 text-red-200'}"
								>
									{t.vagas_sobrando > 0 ? `${t.vagas_sobrando} vaga(s) livre(s)` : 'Sem vagas'}
								</span>
							{/if}
						</div>
						<p class="mt-1 text-xs text-white/65">
							{#if t.docente}{t.docente}{:else}Docente não informado{/if}
							{#if t.horario} · {t.horario}{/if}
							{#if t.local} · {t.local}{/if}
						</p>
						{#if t.vagas_ofertadas != null || t.vagas_ocupadas != null}
							<p class="mt-0.5 text-[11px] text-white/45">
								Ofertadas: {t.vagas_ofertadas ?? '—'} · Ocupadas: {t.vagas_ocupadas ?? '—'}
							</p>
						{/if}
					</div>
					<button
						type="button"
						disabled={acaoEmAndamento === key}
						onclick={() => alternarSeguir(t.turma, t.ano_periodo)}
						class="inline-flex shrink-0 items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-medium transition-colors disabled:opacity-50 {seguindo
							? 'border-purple-300/45 bg-purple-500/18 text-purple-100 hover:bg-purple-500/25'
							: 'border-white/15 bg-white/5 text-white/70 hover:bg-white/10'}"
					>
						{#if acaoEmAndamento === key}
							<Loader2 class="h-3 w-3 animate-spin" />
						{:else if seguindo}
							<Bell class="h-3 w-3" />
						{:else}
							<BellOff class="h-3 w-3" />
						{/if}
						{seguindo ? 'Parar de seguir' : 'Seguir esta turma'}
					</button>
				</div>
			{/each}
		</div>
	{/if}
	{#if carregandoAssinaturas && !carregandoTurmas}
		<p class="mt-2 flex items-center gap-1.5 text-[11px] text-white/40">
			<Loader2 class="h-3 w-3 animate-spin" /> Sincronizando suas assinaturas...
		</p>
	{/if}
</section>
