<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import PageBackground from '$lib/components/effects/PageBackground.svelte';
	import AdminNav from '$lib/components/admin/AdminNav.svelte';
	import { authStore } from '$lib/stores/auth';
	import { ROUTES } from '$lib/config/routes';
	import { hasAdminScope } from '$lib/types/user';
	import {
		systemSettingsService,
		type ScrapingTurmasModo,
		type ScrapingTurmasStatus
	} from '$lib/services/system-settings.service';
	import { AlertTriangle, Loader2, Zap } from 'lucide-svelte';

	let loading = $state(true);
	let saving = $state(false);
	let error = $state<string | null>(null);
	let status = $state<ScrapingTurmasStatus | null>(null);

	const MODOS: { valor: ScrapingTurmasModo; rotulo: string }[] = [
		{ valor: 'auto', rotulo: 'Automático' },
		{ valor: 'on', rotulo: 'Ligado' },
		{ valor: 'off', rotulo: 'Desligado' }
	];

	const FASES: Record<ScrapingTurmasStatus['fase'], string> = {
		pre_matricula: 'pré-matrícula',
		matricula: 'matrícula',
		letivo: 'período letivo',
		recesso: 'recesso',
		desconhecido: 'calendário indisponível'
	};

	const CADENCIAS: Record<ScrapingTurmasStatus['cadencia'], string> = {
		rapida: 'rodando a cada 30 min',
		diaria: 'rodando 1× por dia',
		nenhuma: 'não roda no cron'
	};

	/** '2026-12-14' -> '14/12/2026', sem deslocar o dia pelo fuso do browser. */
	function formatarData(iso: string): string {
		const [ano, mes, dia] = iso.split('-');
		return `${dia}/${mes}/${ano}`;
	}

	function diasRestantes(iso: string): number {
		const alvo = new Date(`${iso}T00:00:00`);
		const hoje = new Date();
		hoje.setHours(0, 0, 0, 0);
		return Math.round((alvo.getTime() - hoje.getTime()) / 86_400_000);
	}

	/** Linha de status: o que a configuração está de fato produzindo hoje. */
	const resumo = $derived.by(() => {
		if (!status) return '';
		const cadencia = CADENCIAS[status.cadencia] ?? status.cadencia;

		if (status.modo === 'off') {
			return 'Desligado · o cron não roda, mas a rodada mensal de base continua.';
		}

		if (status.modo === 'on') {
			if (!status.ativo_ate) {
				return `Ligado sem prazo (calendário vazio) · ${cadencia}.`;
			}
			const dias = diasRestantes(status.ativo_ate);
			// Expiração se mede pela data, não pela cadência: com o prazo vencido
			// numa fase de matrícula o automático também devolve 'rapida', e
			// inferir pela cadência mostraria "-5 dias restantes".
			if (dias < 0) {
				return `O prazo venceu em ${formatarData(status.ativo_ate)} — voltou ao automático · ${cadencia}.`;
			}
			return `Ligado até ${formatarData(status.ativo_ate)} · ${dias} dia${dias === 1 ? '' : 's'} restante${dias === 1 ? '' : 's'} · ${cadencia}.`;
		}

		const fase = FASES[status.fase] ?? status.fase;
		return `Automático · período ${status.periodo} · ${fase} · ${cadencia}.`;
	});

	onMount(() => {
		const state = $authStore;
		if (!state.isAuthenticated || !state.user) {
			goto(`${ROUTES.LOGIN}?redirect=${encodeURIComponent('/admin/configuracoes')}`);
			return;
		}
		if (!hasAdminScope(state.user, 'settings')) {
			goto(`${ROUTES.SUPORTE}?error=access_denied`);
			return;
		}
		void loadSettings();
	});

	async function loadSettings() {
		loading = true;
		error = null;
		try {
			status = await systemSettingsService.getScrapingTurmasStatus();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Erro ao carregar configurações.';
		} finally {
			loading = false;
		}
	}

	async function trocarModo(modo: ScrapingTurmasModo) {
		if (saving || status?.modo === modo) return;
		saving = true;
		error = null;
		try {
			// A RPC devolve a decisão já recalculada (inclusive o ativo_ate novo).
			status = await systemSettingsService.setScrapingTurmasModo(modo);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Erro ao salvar configuração.';
		} finally {
			saving = false;
		}
	}
</script>

<PageMeta title="Configurações — Admin" description="Toggles operacionais do NoFluxoUNB." />

<PageBackground />

<main class="relative z-10 mx-auto w-full max-w-6xl px-4 py-6 sm:py-8">
	<div class="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
		<div>
			<h1 class="text-2xl font-bold text-foreground sm:text-3xl">Configurações</h1>
			<p class="text-sm text-muted-foreground">Toggles operacionais do sistema.</p>
		</div>
		<AdminNav />
	</div>

	{#if loading}
		<div class="flex min-h-[30vh] items-center justify-center gap-3 text-muted-foreground">
			<Loader2 class="h-5 w-5 animate-spin" />
			<span>Carregando configurações…</span>
		</div>
	{:else}
		{#if error}
			<div class="alert mb-4">
				<AlertTriangle class="h-4 w-4 shrink-0" />
				<span>{error}</span>
			</div>
		{/if}

		<section class="card">
			<div class="setting-row">
				<div class="setting-info">
					<h2 class="setting-title"><Zap class="h-4 w-4" /> Cadência do scraping de turmas</h2>
					<p class="setting-desc">
						<strong>Automático</strong> deriva a frequência do calendário acadêmico: a cada 30 min
						na pré-matrícula e na matrícula (até o limite de 25% do semestre), 1× por dia durante
						as aulas, e nada no recesso. <strong>Ligado</strong> força os 30 min até o fim do
						período letivo, e então volta sozinho ao automático. <strong>Desligado</strong> tira o
						cron do ar — a rodada mensal de base continua rodando de qualquer jeito.
					</p>
					{#if status}
						<p class="setting-status">{resumo}</p>
					{/if}
				</div>
				<div class="segmented" role="radiogroup" aria-label="Cadência do scraping de turmas">
					{#each MODOS as opcao (opcao.valor)}
						<button
							type="button"
							role="radio"
							aria-checked={status?.modo === opcao.valor}
							class="segment"
							class:on={status?.modo === opcao.valor}
							disabled={saving || !status}
							onclick={() => trocarModo(opcao.valor)}
						>
							{opcao.rotulo}
						</button>
					{/each}
				</div>
			</div>
		</section>
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
	.card {
		padding: 18px 20px;
		border-radius: 12px;
		background: hsl(var(--card));
		border: 1px solid hsl(var(--border));
	}
	.setting-row {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-start;
		justify-content: space-between;
		gap: 16px;
	}
	.setting-info {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.setting-title {
		display: flex;
		align-items: center;
		gap: 7px;
		font-size: 14px;
		font-weight: 700;
		color: hsl(var(--foreground));
		margin: 0;
	}
	.setting-desc {
		font-size: 13px;
		color: hsl(var(--muted-foreground));
		max-width: 52ch;
		margin: 0;
	}
	.setting-status {
		font-size: 13px;
		font-weight: 600;
		color: hsl(var(--foreground));
		margin: 2px 0 0;
	}
	.segmented {
		display: flex;
		flex-shrink: 0;
		align-self: flex-start;
		border-radius: 8px;
		border: 1px solid hsl(var(--border));
		background: hsl(var(--muted));
		padding: 2px;
		gap: 2px;
	}
	.segment {
		padding: 5px 12px;
		border: none;
		border-radius: 6px;
		background: transparent;
		font-size: 13px;
		font-weight: 600;
		color: hsl(var(--muted-foreground));
		cursor: pointer;
		white-space: nowrap;
		transition:
			background 150ms ease,
			color 150ms ease;
	}
	.segment:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
	.segment.on {
		background: hsl(var(--primary));
		color: hsl(var(--primary-foreground));
	}
</style>
