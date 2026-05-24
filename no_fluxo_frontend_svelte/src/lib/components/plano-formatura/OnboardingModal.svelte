<script lang="ts">
	import type { PreferenciasPlano } from '$lib/types/plano-formatura';
	import { DEFAULT_PREFERENCIAS } from '$lib/types/plano-formatura';
	import { GraduationCap, Briefcase, Zap, Scale, ChevronRight, X } from 'lucide-svelte';
	import { fade, fly } from 'svelte/transition';

	interface Props {
		open: boolean;
		onConfirm: (prefs: PreferenciasPlano) => void;
		onClose: () => void;
	}

	let { open, onConfirm, onClose }: Props = $props();

	let step = $state(1);
	const TOTAL_STEPS = 3;

	let trabalha = $state(DEFAULT_PREFERENCIAS.trabalha);
	let limiteCreditos = $state<number>(DEFAULT_PREFERENCIAS.limiteCreditos);
	let objetivo = $state<'velocidade' | 'equilibrio'>(DEFAULT_PREFERENCIAS.objetivo);

	function next() {
		if (step < TOTAL_STEPS) step++;
	}

	function prev() {
		if (step > 1) step--;
	}

	function confirm() {
		onConfirm({
			trabalha,
			limiteCreditos,
			objetivo,
			onboardingConcluido: true
		});
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onClose();
	}

	const stepTitles = [
		'Você trabalha ou estagia?',
		'Quantos créditos por semestre?',
		'Qual é o seu objetivo?'
	];
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
	<!-- Backdrop -->
	<div
		class="fixed inset-0 z-50 flex items-center justify-center p-4"
		transition:fade={{ duration: 180 }}
		role="dialog"
		aria-modal="true"
		aria-label="Configurar plano de formatura"
	>
		<!-- Overlay -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div
			class="absolute inset-0 bg-black/70 backdrop-blur-sm"
			onclick={onClose}
			onkeydown={(e) => e.key === 'Enter' && onClose()}
		></div>

		<!-- Modal panel -->
		<div
			class="relative z-10 w-full max-w-md overflow-hidden rounded-2xl border border-white/10 bg-[#0e1117] shadow-2xl"
			transition:fly={{ y: 24, duration: 250 }}
		>
			<!-- Header -->
			<div class="relative border-b border-white/8 px-6 py-5">
				<div class="flex items-center gap-3">
					<div class="flex h-9 w-9 items-center justify-center rounded-xl bg-blue-600/20">
						<GraduationCap class="h-5 w-5 text-blue-400" />
					</div>
					<div>
						<p class="text-[11px] font-semibold uppercase tracking-widest text-blue-400">
							Configurar plano
						</p>
						<h2 class="text-base font-semibold text-white leading-tight">
							Plano de Formatura
						</h2>
					</div>
				</div>
				<button
					type="button"
					onclick={onClose}
					class="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-lg text-white/40 transition-colors hover:bg-white/8 hover:text-white/80"
					aria-label="Fechar"
				>
					<X class="h-4 w-4" />
				</button>
			</div>

			<!-- Progress bar -->
			<div class="h-0.5 bg-white/6">
				<div
					class="h-full bg-blue-500 transition-all duration-400 ease-out"
					style="width: {(step / TOTAL_STEPS) * 100}%"
				></div>
			</div>

			<!-- Step content -->
			<div class="px-6 py-7">
				<!-- Step indicator -->
				<p class="mb-1 text-[11px] font-medium text-white/35">
					Passo {step} de {TOTAL_STEPS}
				</p>
				<h3 class="mb-6 text-lg font-semibold text-white">
					{stepTitles[step - 1]}
				</h3>

				{#if step === 1}
					<!-- Question 1: trabalha? -->
					<div class="flex flex-col gap-3">
						<button
							type="button"
							onclick={() => { trabalha = true; }}
							class="group flex items-center gap-4 rounded-xl border px-4 py-4 text-left transition-all duration-150
								{trabalha
									? 'border-blue-500/60 bg-blue-600/12 ring-1 ring-blue-500/30'
									: 'border-white/10 bg-white/4 hover:border-white/20 hover:bg-white/7'}"
						>
							<div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg
								{trabalha ? 'bg-blue-500/20 text-blue-400' : 'bg-white/6 text-white/50 group-hover:text-white/70'}">
								<Briefcase class="h-5 w-5" />
							</div>
							<div>
								<p class="text-sm font-medium text-white">Sim, trabalho ou estagio</p>
								<p class="mt-0.5 text-xs text-white/45">Carga sugerida mais leve</p>
							</div>
							{#if trabalha}
								<div class="ml-auto h-2 w-2 rounded-full bg-blue-400"></div>
							{/if}
						</button>

						<button
							type="button"
							onclick={() => { trabalha = false; }}
							class="group flex items-center gap-4 rounded-xl border px-4 py-4 text-left transition-all duration-150
								{!trabalha
									? 'border-blue-500/60 bg-blue-600/12 ring-1 ring-blue-500/30'
									: 'border-white/10 bg-white/4 hover:border-white/20 hover:bg-white/7'}"
						>
							<div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg
								{!trabalha ? 'bg-blue-500/20 text-blue-400' : 'bg-white/6 text-white/50 group-hover:text-white/70'}">
								<GraduationCap class="h-5 w-5" />
							</div>
							<div>
								<p class="text-sm font-medium text-white">Não, só estudo</p>
								<p class="mt-0.5 text-xs text-white/45">Pode assumir carga maior</p>
							</div>
							{#if !trabalha}
								<div class="ml-auto h-2 w-2 rounded-full bg-blue-400"></div>
							{/if}
						</button>
					</div>

				{:else if step === 2}
					<!-- Question 2: limite de créditos -->
					<div class="flex flex-col gap-3">
						{#each ([16, 24, 32] as const) as limite}
							{@const labels: Record<number, { subtitle: string }> = {
								16: { subtitle: 'Leve — mais fôlego no semestre' },
								24: { subtitle: 'Moderado — equilíbrio recomendado' },
								32: { subtitle: 'Intenso — velocidade máxima' }
							}}
							<button
								type="button"
								onclick={() => { limiteCreditos = limite; }}
								class="group flex items-center gap-4 rounded-xl border px-4 py-4 text-left transition-all duration-150
									{limiteCreditos === limite
										? 'border-blue-500/60 bg-blue-600/12 ring-1 ring-blue-500/30'
										: 'border-white/10 bg-white/4 hover:border-white/20 hover:bg-white/7'}"
							>
								<div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg font-mono text-sm font-bold
									{limiteCreditos === limite ? 'bg-blue-500/20 text-blue-300' : 'bg-white/6 text-white/50 group-hover:text-white/70'}">
									{limite}
								</div>
								<div>
									<p class="text-sm font-medium text-white">{limite} créditos</p>
									<p class="mt-0.5 text-xs text-white/45">{labels[limite].subtitle}</p>
								</div>
								{#if limiteCreditos === limite}
									<div class="ml-auto h-2 w-2 rounded-full bg-blue-400"></div>
								{/if}
							</button>
						{/each}
					</div>

				{:else if step === 3}
					<!-- Question 3: objetivo -->
					<div class="flex flex-col gap-3">
						<button
							type="button"
							onclick={() => { objetivo = 'velocidade'; }}
							class="group flex items-center gap-4 rounded-xl border px-4 py-4 text-left transition-all duration-150
								{objetivo === 'velocidade'
									? 'border-blue-500/60 bg-blue-600/12 ring-1 ring-blue-500/30'
									: 'border-white/10 bg-white/4 hover:border-white/20 hover:bg-white/7'}"
						>
							<div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg
								{objetivo === 'velocidade' ? 'bg-blue-500/20 text-blue-400' : 'bg-white/6 text-white/50 group-hover:text-white/70'}">
								<Zap class="h-5 w-5" />
							</div>
							<div>
								<p class="text-sm font-medium text-white">Velocidade máxima</p>
								<p class="mt-0.5 text-xs text-white/45">Prioriza se formar mais rápido</p>
							</div>
							{#if objetivo === 'velocidade'}
								<div class="ml-auto h-2 w-2 rounded-full bg-blue-400"></div>
							{/if}
						</button>

						<button
							type="button"
							onclick={() => { objetivo = 'equilibrio'; }}
							class="group flex items-center gap-4 rounded-xl border px-4 py-4 text-left transition-all duration-150
								{objetivo === 'equilibrio'
									? 'border-blue-500/60 bg-blue-600/12 ring-1 ring-blue-500/30'
									: 'border-white/10 bg-white/4 hover:border-white/20 hover:bg-white/7'}"
						>
							<div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg
								{objetivo === 'equilibrio' ? 'bg-blue-500/20 text-blue-400' : 'bg-white/6 text-white/50 group-hover:text-white/70'}">
								<Scale class="h-5 w-5" />
							</div>
							<div>
								<p class="text-sm font-medium text-white">Equilíbrio</p>
								<p class="mt-0.5 text-xs text-white/45">Distribui melhor a carga ao longo do tempo</p>
							</div>
							{#if objetivo === 'equilibrio'}
								<div class="ml-auto h-2 w-2 rounded-full bg-blue-400"></div>
							{/if}
						</button>
					</div>
				{/if}
			</div>

			<!-- Footer actions -->
			<div class="flex items-center justify-between border-t border-white/8 px-6 py-4">
				{#if step > 1}
					<button
						type="button"
						onclick={prev}
						class="text-sm font-medium text-white/45 transition-colors hover:text-white/70"
					>
						Voltar
					</button>
				{:else}
					<div></div>
				{/if}

				{#if step < TOTAL_STEPS}
					<button
						type="button"
						onclick={next}
						class="flex items-center gap-1.5 rounded-lg bg-blue-600 px-5 py-2 text-sm font-semibold text-white transition-colors hover:bg-blue-500 active:bg-blue-700"
					>
						Próximo
						<ChevronRight class="h-4 w-4" />
					</button>
				{:else}
					<button
						type="button"
						onclick={confirm}
						class="flex items-center gap-1.5 rounded-lg bg-blue-600 px-5 py-2 text-sm font-semibold text-white transition-colors hover:bg-blue-500 active:bg-blue-700"
					>
						<GraduationCap class="h-4 w-4" />
						Gerar meu plano
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}
