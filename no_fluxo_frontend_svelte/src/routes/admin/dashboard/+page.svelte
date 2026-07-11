<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import PageBackground from '$lib/components/effects/PageBackground.svelte';
	import AdminNav from '$lib/components/admin/AdminNav.svelte';
	import { authStore } from '$lib/stores/auth';
	import { ROUTES } from '$lib/config/routes';
	import { hasAdminScope } from '$lib/types/user';
	import { dashboardService } from '$lib/services/dashboard.service';
	import {
		CATEGORY_LABELS,
		STATUS_LABELS,
		type TicketCategory,
		type TicketStatus
	} from '$lib/types/ticket';
	import type {
		AiCostMetrics,
		DashboardOverview,
		ScrapingHealth,
		TicketMetrics,
		TopCurso,
		TurmasDemanda,
		UserGrowthPoint
	} from '$lib/types/dashboard';
	import {
		AlertTriangle,
		Loader2,
		TrendingUp,
		Users,
		FileCheck2,
		GitBranch,
		LifeBuoy,
		Bot,
		CalendarClock,
		Database
	} from 'lucide-svelte';

	let loading = $state(true);
	let error = $state<string | null>(null);

	let overview = $state<DashboardOverview | null>(null);
	let growth = $state<UserGrowthPoint[]>([]);
	let topCursos = $state<TopCurso[]>([]);
	let ticketMetrics = $state<TicketMetrics | null>(null);
	let aiCost = $state<AiCostMetrics | null>(null);
	let turmas = $state<TurmasDemanda | null>(null);
	let scraping = $state<ScrapingHealth | null>(null);

	const maxGrowth = $derived(Math.max(1, ...growth.map((g) => g.novos)));
	const maxCurso = $derived(Math.max(1, ...topCursos.map((c) => c.usuarios)));
	const maxAiDay = $derived(Math.max(1, ...(aiCost?.por_dia ?? []).map((d) => d.custo)));
	const moedaFmt = $derived((v: number) =>
		new Intl.NumberFormat('pt-BR', {
			style: 'currency',
			currency: aiCost?.moeda || 'BRL'
		}).format(v ?? 0)
	);

	onMount(() => {
		const state = $authStore;
		if (!state.isAuthenticated || !state.user) {
			goto(`${ROUTES.LOGIN}?redirect=${encodeURIComponent('/admin/dashboard')}`);
			return;
		}
		if (!hasAdminScope(state.user, 'dashboard')) {
			goto(`${ROUTES.SUPORTE}?error=access_denied`);
			return;
		}
		void loadAll();
	});

	async function loadAll() {
		loading = true;
		error = null;
		try {
			const [o, g, t, m, ai, tu, sc] = await Promise.all([
				dashboardService.getOverview(),
				dashboardService.getUserGrowth(30, 'day'),
				dashboardService.getTopCursos(8),
				dashboardService.getTicketMetrics(),
				dashboardService.getAiCostMetrics(30),
				dashboardService.getTurmasDemanda(),
				dashboardService.getScrapingHealth()
			]);
			overview = o;
			growth = g;
			topCursos = t;
			ticketMetrics = m;
			aiCost = ai;
			turmas = tu;
			scraping = sc;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Erro ao carregar o dashboard.';
		} finally {
			loading = false;
		}
	}

	function fmtDate(value: string): string {
		try {
			return new Date(value).toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' });
		} catch {
			return value;
		}
	}
</script>

<PageMeta title="Dashboard — Admin" description="Métricas do NoFluxoUNB." />

<PageBackground />

<main class="relative z-10 mx-auto w-full max-w-6xl px-4 py-6 sm:py-8">
	<div class="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
		<div>
			<h1 class="text-2xl font-bold text-foreground sm:text-3xl">Dashboard</h1>
			<p class="text-sm text-muted-foreground">Visão geral do produto e do suporte.</p>
		</div>
		<AdminNav />
	</div>

	{#if loading}
		<div class="flex min-h-[50vh] items-center justify-center gap-3 text-muted-foreground">
			<Loader2 class="h-5 w-5 animate-spin" />
			<span>Carregando métricas…</span>
		</div>
	{:else if error}
		<div class="alert">
			<AlertTriangle class="h-4 w-4 shrink-0" />
			<span>{error}</span>
		</div>
	{:else if overview}
		<!-- Stat cards -->
		<section class="grid grid-cols-2 gap-3 lg:grid-cols-4">
			<div class="stat">
				<Users class="h-5 w-5 text-primary" />
				<span class="stat-value">{overview.total_users.toLocaleString('pt-BR')}</span>
				<span class="stat-label">Usuários</span>
				<span class="stat-sub">+{overview.novos_users_30d} em 30d</span>
			</div>
			<div class="stat">
				<FileCheck2 class="h-5 w-5 text-primary" />
				<span class="stat-value">{overview.com_historico.toLocaleString('pt-BR')}</span>
				<span class="stat-label">Importaram histórico</span>
			</div>
			<div class="stat">
				<GitBranch class="h-5 w-5 text-primary" />
				<span class="stat-value">{overview.com_fluxograma.toLocaleString('pt-BR')}</span>
				<span class="stat-label">Fluxograma salvo</span>
				<span class="stat-sub">{overview.taxa_ativacao}% ativação</span>
			</div>
			<div class="stat">
				<LifeBuoy class="h-5 w-5 text-primary" />
				<span class="stat-value">{overview.tickets_abertos}</span>
				<span class="stat-label">Tickets abertos</span>
			</div>
		</section>

		<!-- Funil de ativação -->
		<section class="card mt-5">
			<h2 class="card-title">Funil de ativação</h2>
			<div class="funnel">
				{#each [{ l: 'Cadastrou', v: overview.total_users }, { l: 'Importou histórico', v: overview.com_historico }, { l: 'Salvou fluxograma', v: overview.com_fluxograma }] as step}
					<div class="funnel-row">
						<span class="funnel-label">{step.l}</span>
						<div class="funnel-track">
							<div
								class="funnel-fill"
								style="width: {overview.total_users > 0
									? (step.v / overview.total_users) * 100
									: 0}%"
							></div>
						</div>
						<span class="funnel-value">{step.v.toLocaleString('pt-BR')}</span>
					</div>
				{/each}
			</div>
		</section>

		<div class="mt-5 grid gap-5 lg:grid-cols-2">
			<!-- Crescimento -->
			<section class="card">
				<h2 class="card-title">
					<TrendingUp class="h-4 w-4" /> Novos cadastros (30 dias)
				</h2>
				{#if growth.length === 0}
					<p class="empty">Sem cadastros no período.</p>
				{:else}
					<div class="bars">
						{#each growth as g}
							<div class="bar-col" title={`${fmtDate(g.bucket)}: ${g.novos} novos`}>
								<div class="bar" style="height: {(g.novos / maxGrowth) * 100}%"></div>
							</div>
						{/each}
					</div>
					<div class="bars-axis">
						<span>{fmtDate(growth[0].bucket)}</span>
						<span>{fmtDate(growth[growth.length - 1].bucket)}</span>
					</div>
				{/if}
			</section>

			<!-- Top cursos -->
			<section class="card">
				<h2 class="card-title">Cursos mais usados</h2>
				{#if topCursos.length === 0}
					<p class="empty">Sem dados.</p>
				{:else}
					<ul class="ranklist">
						{#each topCursos as c}
							<li class="rank-row">
								<span class="rank-label" title={c.curso}>{c.curso}</span>
								<div class="rank-track">
									<div class="rank-fill" style="width: {(c.usuarios / maxCurso) * 100}%"></div>
								</div>
								<span class="rank-value">{c.usuarios}</span>
							</li>
						{/each}
					</ul>
				{/if}
			</section>
		</div>

		<!-- Tickets -->
		{#if ticketMetrics}
			<section class="card mt-5">
				<h2 class="card-title">Suporte</h2>
				<div class="ticket-grid">
					<div class="ticket-block">
						<span class="block-title">Total</span>
						<span class="block-big">{ticketMetrics.total}</span>
						<span class="block-sub">
							Tempo médio resolução: {ticketMetrics.tempo_medio_horas}h
						</span>
					</div>
					<div class="ticket-block">
						<span class="block-title">Por status</span>
						<ul class="kv">
							{#each Object.entries(ticketMetrics.por_status) as [k, v]}
								<li>
									<span>{STATUS_LABELS[k as TicketStatus] ?? k}</span><strong>{v}</strong>
								</li>
							{/each}
						</ul>
					</div>
					<div class="ticket-block">
						<span class="block-title">Por categoria</span>
						<ul class="kv">
							{#each Object.entries(ticketMetrics.por_categoria) as [k, v]}
								<li>
									<span>{CATEGORY_LABELS[k as TicketCategory] ?? k}</span><strong>{v}</strong>
								</li>
							{/each}
						</ul>
					</div>
				</div>
				<a class="ticket-link" href={ROUTES.ADMIN_TICKETS}>Ver todos os tickets →</a>
			</section>
		{/if}

		<!-- Custos de IA -->
		{#if aiCost}
			<section class="card mt-5">
				<h2 class="card-title"><Bot class="h-4 w-4" /> Custos de IA (30 dias)</h2>
				{#if aiCost.precos_nao_configurados}
					<div class="alert mb-3">
						<AlertTriangle class="h-4 w-4 shrink-0" />
						<span>
							Preços não configurados — defina <code>input_per_1k</code>/<code
								>output_per_1k</code
							> na tabela <code>ai_pricing</code> para o custo refletir valores reais.
						</span>
					</div>
				{/if}
				<div class="ticket-grid">
					<div class="ticket-block">
						<span class="block-title">Custo total</span>
						<span class="block-big">{moedaFmt(aiCost.custo_total)}</span>
						<span class="block-sub">{aiCost.total_requisicoes} requisições</span>
					</div>
					<div class="ticket-block">
						<span class="block-title">Tokens</span>
						<span class="block-big">{aiCost.total_tokens.toLocaleString('pt-BR')}</span>
						<span class="block-sub">~{aiCost.tokens_medios_por_req} por requisição</span>
					</div>
					<div class="ticket-block">
						<span class="block-title">Por modelo</span>
						<ul class="kv">
							{#each Object.entries(aiCost.por_modelo) as [model, m]}
								<li>
									<span>{model}</span><strong>{moedaFmt(m.custo)}</strong>
								</li>
							{:else}
								<li><span>Sem dados</span></li>
							{/each}
						</ul>
					</div>
				</div>
				{#if aiCost.por_dia.length > 0}
					<div class="mt-4">
						<span class="block-title">Custo por dia</span>
						<div class="bars mt-2">
							{#each aiCost.por_dia as d}
								<div class="bar-col" title={`${fmtDate(d.dia)}: ${moedaFmt(d.custo)}`}>
									<div class="bar" style="height: {(d.custo / maxAiDay) * 100}%"></div>
								</div>
							{/each}
						</div>
					</div>
				{/if}
			</section>
		{/if}

		<!-- Demanda de turmas -->
		{#if turmas}
			<section class="card mt-5">
				<h2 class="card-title">
					<CalendarClock class="h-4 w-4" /> Demanda de turmas — {turmas.periodo || '—'}
				</h2>
				<div class="ticket-grid">
					<div class="ticket-block">
						<span class="block-title">Ocupação</span>
						<span class="block-big">{turmas.taxa_ocupacao}%</span>
						<span class="block-sub">
							{turmas.vagas_ocupadas.toLocaleString('pt-BR')} /
							{turmas.vagas_ofertadas.toLocaleString('pt-BR')} vagas
						</span>
					</div>
					<div class="ticket-block">
						<span class="block-title">Vagas sobrando</span>
						<span class="block-big">{turmas.vagas_sobrando.toLocaleString('pt-BR')}</span>
					</div>
				</div>
				{#if turmas.top_concorridas.length > 0}
					<span class="block-title mt-4 block">Matérias mais concorridas</span>
					<ul class="ranklist mt-2">
						{#each turmas.top_concorridas as t}
							<li class="rank-row">
								<span class="rank-label" title={`${t.codigo} — ${t.nome}`}>
									{t.codigo} · {t.nome}
								</span>
								<div class="rank-track">
									<div class="rank-fill" style="width: {Math.min(100, t.ocupacao)}%"></div>
								</div>
								<span class="rank-value">{t.ocupacao}%</span>
							</li>
						{/each}
					</ul>
				{/if}
			</section>
		{/if}

		<!-- Saúde do scraping -->
		{#if scraping}
			<section class="card mt-5">
				<h2 class="card-title"><Database class="h-4 w-4" /> Saúde do catálogo</h2>
				<div class="ticket-grid">
					<div class="ticket-block">
						<span class="block-title">Turmas atualizadas em</span>
						<span class="block-big">
							{scraping.turmas_atualizado_em
								? fmtDate(scraping.turmas_atualizado_em)
								: '—'}
						</span>
						<span class="block-sub">
							mais antigo: {scraping.turmas_mais_antigo_em
								? fmtDate(scraping.turmas_mais_antigo_em)
								: '—'}
						</span>
					</div>
					<div class="ticket-block">
						<span class="block-title">Matérias sem ementa</span>
						<span class="block-big">{scraping.materias_sem_ementa_pct}%</span>
						<span class="block-sub">
							{scraping.materias_sem_ementa.toLocaleString('pt-BR')} de
							{scraping.materias_total.toLocaleString('pt-BR')}
						</span>
					</div>
					<div class="ticket-block">
						<span class="block-title">Cursos sem matriz</span>
						<span class="block-big">{scraping.cursos_sem_matriz}</span>
					</div>
				</div>
			</section>
		{/if}
	{/if}
</main>

<style>
	.alert {
		display: flex;
		gap: 10px;
		padding: 12px 14px;
		border-radius: 8px;
		font-size: 13px;
		background: hsl(var(--destructive) / 0.12);
		border: 1px solid hsl(var(--destructive) / 0.3);
		color: hsl(var(--destructive));
	}
	.stat {
		display: flex;
		flex-direction: column;
		gap: 4px;
		padding: 16px;
		border-radius: 12px;
		background: hsl(var(--card));
		border: 1px solid hsl(var(--border));
	}
	.stat-value {
		font-size: 26px;
		font-weight: 700;
		color: hsl(var(--foreground));
		line-height: 1.1;
		margin-top: 4px;
	}
	.stat-label {
		font-size: 12px;
		color: hsl(var(--muted-foreground));
	}
	.stat-sub {
		font-size: 11px;
		color: hsl(var(--primary));
		font-weight: 600;
	}
	.card {
		padding: 18px 20px;
		border-radius: 12px;
		background: hsl(var(--card));
		border: 1px solid hsl(var(--border));
	}
	.card-title {
		display: flex;
		align-items: center;
		gap: 7px;
		font-size: 14px;
		font-weight: 700;
		color: hsl(var(--foreground));
		margin: 0 0 14px;
	}
	.empty {
		color: hsl(var(--muted-foreground));
		font-size: 13px;
	}
	/* Funnel */
	.funnel {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}
	.funnel-row {
		display: grid;
		grid-template-columns: 140px 1fr 60px;
		align-items: center;
		gap: 12px;
	}
	.funnel-label {
		font-size: 13px;
		color: hsl(var(--muted-foreground));
	}
	.funnel-track {
		height: 22px;
		border-radius: 6px;
		background: hsl(var(--muted) / 0.5);
		overflow: hidden;
	}
	.funnel-fill {
		height: 100%;
		background: linear-gradient(90deg, hsl(var(--primary)), hsl(var(--primary) / 0.6));
		border-radius: 6px;
		transition: width 400ms ease;
	}
	.funnel-value {
		font-size: 13px;
		font-weight: 700;
		color: hsl(var(--foreground));
		text-align: right;
	}
	/* Bars */
	.bars {
		display: flex;
		align-items: flex-end;
		gap: 3px;
		height: 140px;
	}
	.bar-col {
		flex: 1;
		display: flex;
		align-items: flex-end;
		height: 100%;
	}
	.bar {
		width: 100%;
		min-height: 2px;
		background: hsl(var(--primary));
		border-radius: 3px 3px 0 0;
		transition: height 400ms ease;
	}
	.bars-axis {
		display: flex;
		justify-content: space-between;
		margin-top: 6px;
		font-size: 11px;
		color: hsl(var(--muted-foreground));
	}
	/* Rank */
	.ranklist {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	.rank-row {
		display: grid;
		grid-template-columns: 140px 1fr 36px;
		align-items: center;
		gap: 10px;
	}
	.rank-label {
		font-size: 12px;
		color: hsl(var(--foreground));
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.rank-track {
		height: 8px;
		border-radius: 4px;
		background: hsl(var(--muted) / 0.5);
		overflow: hidden;
	}
	.rank-fill {
		height: 100%;
		background: hsl(var(--primary));
		border-radius: 4px;
	}
	.rank-value {
		font-size: 12px;
		font-weight: 700;
		color: hsl(var(--foreground));
		text-align: right;
	}
	/* Tickets */
	.ticket-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
		gap: 16px;
	}
	.ticket-block {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.block-title {
		font-size: 11px;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: hsl(var(--muted-foreground));
		font-weight: 700;
	}
	.block-big {
		font-size: 24px;
		font-weight: 700;
		color: hsl(var(--foreground));
	}
	.block-sub {
		font-size: 12px;
		color: hsl(var(--muted-foreground));
	}
	.kv {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}
	.kv li {
		display: flex;
		justify-content: space-between;
		font-size: 13px;
		color: hsl(var(--muted-foreground));
	}
	.kv strong {
		color: hsl(var(--foreground));
	}
	.ticket-link {
		display: inline-block;
		margin-top: 14px;
		font-size: 13px;
		font-weight: 600;
		color: hsl(var(--primary));
		text-decoration: none;
	}
	.ticket-link:hover {
		text-decoration: underline;
	}
</style>
