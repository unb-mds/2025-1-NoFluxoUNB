<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import PageBackground from '$lib/components/effects/PageBackground.svelte';
	import AdminNav from '$lib/components/admin/AdminNav.svelte';
	import { authStore } from '$lib/stores/auth';
	import { ROUTES } from '$lib/config/routes';
	import { hasAdminScope } from '$lib/types/user';
	import { systemSettingsService } from '$lib/services/system-settings.service';
	import { AlertTriangle, Loader2, Zap } from 'lucide-svelte';

	let loading = $state(true);
	let saving = $state(false);
	let error = $state<string | null>(null);
	let scrapingTurmasRapido = $state(false);

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
			scrapingTurmasRapido = await systemSettingsService.getScrapingTurmasRapido();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Erro ao carregar configurações.';
		} finally {
			loading = false;
		}
	}

	async function toggleScrapingTurmasRapido() {
		const novoValor = !scrapingTurmasRapido;
		saving = true;
		error = null;
		try {
			await systemSettingsService.setScrapingTurmasRapido(novoValor);
			scrapingTurmasRapido = novoValor;
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
					<h2 class="setting-title"><Zap class="h-4 w-4" /> Scraping rápido de turmas</h2>
					<p class="setting-desc">
						Quando ligado, o scraping de turmas roda a cada 15 minutos (em vez de só na rodada
						mensal de base). Ligar durante a época de matrícula, pra manter vagas sobrando
						atualizadas com mais frequência. Desligar fora desse período.
					</p>
				</div>
				<button
					type="button"
					role="switch"
					aria-checked={scrapingTurmasRapido}
					aria-label="Ativar scraping rápido de turmas"
					class="switch"
					class:on={scrapingTurmasRapido}
					disabled={saving}
					onclick={toggleScrapingTurmasRapido}
				>
					<span class="switch-thumb"></span>
				</button>
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
	.switch {
		position: relative;
		flex-shrink: 0;
		width: 44px;
		height: 24px;
		border-radius: 999px;
		border: 1px solid hsl(var(--border));
		background: hsl(var(--muted));
		cursor: pointer;
		transition: background 150ms ease;
	}
	.switch:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
	.switch.on {
		background: hsl(var(--primary));
		border-color: hsl(var(--primary));
	}
	.switch-thumb {
		position: absolute;
		top: 2px;
		left: 2px;
		width: 18px;
		height: 18px;
		border-radius: 50%;
		background: white;
		transition: transform 150ms ease;
	}
	.switch.on .switch-thumb {
		transform: translateX(20px);
	}
</style>
