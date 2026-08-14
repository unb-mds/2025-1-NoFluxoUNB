<script lang="ts">
	/**
	 * Modal de novidades do release — aparece UMA vez por usuário por RELEASE_ID
	 * (marcado em localStorage). Se o fluxograma salvo do usuário for de uma
	 * versão de schema anterior, destaca o convite para reenviar o histórico —
	 * é o reenvio que ativa os recursos que dependem de dado novo (módulo
	 * livre, equivalências do próprio histórico). Nunca bloqueia: fechar segue
	 * usando o app normalmente.
	 */
	import { browser } from '$app/environment';
	import { goto } from '$app/navigation';
	import { fade, fly } from 'svelte/transition';
	import { Sparkles, X, Upload, PartyPopper } from 'lucide-svelte';
	import { authStore } from '$lib/stores/auth';
	import { ROUTES } from '$lib/config/routes';
	import {
		RELEASE_ID,
		RELEASE_TITULO,
		RELEASE_NOVIDADES,
		FLUXOGRAMA_SCHEMA_VERSION
	} from '$lib/config/release';

	let authState = $derived($authStore);
	let visivel = $state(false);

	const chaveStorage = (idUser: number) => `nofluxo:release-vista:${idUser}`;

	$effect(() => {
		if (!browser) return;
		const u = authState.user;
		if (!u || authState.isLoading) return;
		try {
			if (localStorage.getItem(chaveStorage(u.idUser)) === RELEASE_ID) return;
		} catch {
			return; // sem localStorage (ex.: modo privativo estrito): não insiste
		}
		visivel = true;
	});

	/** Já enviou histórico alguma vez, mas com o schema antigo (ou sem versão). */
	const dadosDesatualizados = $derived.by(() => {
		const dados = authState.user?.dadosFluxograma;
		if (!dados) return false;
		return (dados.schemaVersion ?? 1) < FLUXOGRAMA_SCHEMA_VERSION;
	});

	function marcarVisto() {
		const u = authState.user;
		if (u) {
			try {
				localStorage.setItem(chaveStorage(u.idUser), RELEASE_ID);
			} catch {
				/* sem localStorage: paciência, mostra de novo na próxima */
			}
		}
		visivel = false;
	}

	function reenviarHistorico() {
		marcarVisto();
		goto(ROUTES.UPLOAD_HISTORICO);
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape' && visivel) marcarVisto();
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if visivel}
	<div
		class="fixed inset-0 z-[110] flex items-center justify-center p-4"
		transition:fade={{ duration: 180 }}
		role="dialog"
		aria-modal="true"
		aria-label={RELEASE_TITULO}
	>
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div
			class="absolute inset-0 bg-black/70 backdrop-blur-sm"
			onclick={marcarVisto}
			onkeydown={(e) => e.key === 'Enter' && marcarVisto()}
		></div>

		<div
			class="relative z-10 w-full max-w-md overflow-hidden rounded-2xl border border-white/10 bg-[#0e1117] shadow-2xl"
			transition:fly={{ y: 24, duration: 250 }}
		>
			<!-- Header -->
			<div class="relative border-b border-white/8 px-6 py-5">
				<div class="flex items-center gap-3">
					<div class="flex h-9 w-9 items-center justify-center rounded-xl bg-pink-500/15">
						<PartyPopper class="h-5 w-5 text-pink-400" />
					</div>
					<div>
						<p class="text-[11px] font-semibold uppercase tracking-widest text-pink-400">
							Atualização
						</p>
						<h2 class="text-base font-semibold leading-tight text-white">{RELEASE_TITULO}</h2>
					</div>
				</div>
				<button
					type="button"
					onclick={marcarVisto}
					class="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-lg text-white/40 transition-colors hover:bg-white/8 hover:text-white/80"
					aria-label="Fechar"
				>
					<X class="h-4 w-4" />
				</button>
			</div>

			<!-- Novidades -->
			<div class="px-6 py-6">
				<ul class="flex flex-col gap-3">
					{#each RELEASE_NOVIDADES as novidade}
						<li class="flex items-start gap-2.5">
							<Sparkles class="mt-0.5 h-3.5 w-3.5 shrink-0 text-indigo-400" />
							<span class="text-[13.5px] leading-relaxed text-white/80">{novidade}</span>
						</li>
					{/each}
				</ul>

				{#if dadosDesatualizados}
					<div class="mt-5 rounded-xl border border-amber-500/25 bg-amber-600/10 px-4 py-3.5">
						<p class="text-xs leading-relaxed text-amber-200/85">
							Seu histórico foi enviado antes dessas melhorias. Para o fluxograma reconhecer
							<strong class="text-amber-100">módulo livre e equivalências</strong> com os dados
							novos, reenvie o PDF do histórico — leva menos de um minuto.
						</p>
					</div>
				{/if}
			</div>

			<!-- Ações -->
			<div class="flex items-center justify-between gap-3 border-t border-white/8 px-6 py-4">
				<button
					type="button"
					onclick={marcarVisto}
					class="text-sm font-medium text-white/45 transition-colors hover:text-white/70"
				>
					{dadosDesatualizados ? 'Agora não' : 'Entendi'}
				</button>
				{#if dadosDesatualizados}
					<button
						type="button"
						onclick={reenviarHistorico}
						class="flex items-center gap-1.5 rounded-lg bg-pink-600 px-5 py-2 text-sm font-semibold text-white transition-colors hover:bg-pink-500 active:bg-pink-700"
					>
						<Upload class="h-4 w-4" />
						Reenviar histórico
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}
