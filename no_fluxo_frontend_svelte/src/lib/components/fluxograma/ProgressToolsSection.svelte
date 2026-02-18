<script lang="ts">
	import { Calculator, TrendingUp, GraduationCap, ArrowRightLeft } from 'lucide-svelte';
	import { toast } from 'svelte-sonner';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';

	const store = fluxogramaStore;

	const tools = [
		{
			id: 'ira',
			icon: Calculator,
			title: 'Calculadora de IRA',
			description: 'Simule seu Índice de Rendimento Acadêmico',
			color: 'text-blue-400',
			bgColor: 'from-blue-500/10 to-blue-700/5'
		},
		{
			id: 'progress',
			icon: TrendingUp,
			title: 'Progresso do Curso',
			description: 'Visualize créditos por tipo e área',
			color: 'text-purple-400',
			bgColor: 'from-purple-500/10 to-purple-700/5'
		},
		{
			id: 'integralizacao',
			icon: GraduationCap,
			title: 'Integralização',
			description: 'Requisitos para formatura',
			color: 'text-green-400',
			bgColor: 'from-green-500/10 to-green-700/5'
		},
		{
			id: 'mudanca',
			icon: ArrowRightLeft,
			title: 'Mudança de Curso',
			description: 'Simule transferência entre cursos',
			color: 'text-amber-400',
			bgColor: 'from-amber-500/10 to-amber-700/5'
		}
	];

	function handleToolClick(toolId: string) {
		if (store.state.isAnonymous) {
			toast.error('Faça login para usar esta ferramenta.');
			return;
		}
		toast.info('Em breve! Esta funcionalidade está em desenvolvimento.');
	}
</script>

<div class="rounded-xl border border-white/10 bg-black/40 p-4 backdrop-blur-md">
	<h3 class="mb-3 text-xs font-semibold uppercase tracking-wider text-white/50">
		Ferramentas
	</h3>
	<div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
		{#each tools as tool}
			<button
				onclick={() => handleToolClick(tool.id)}
				class="group relative overflow-hidden rounded-xl border border-white/10 bg-gradient-to-br {tool.bgColor} p-4 text-left transition-all hover:border-white/20 hover:shadow-lg"
			>
				<div class="absolute right-2 top-2 rounded-full bg-white/10 px-2 py-0.5 text-[10px] font-medium text-white/40">
					Em breve
				</div>
				<div class="mb-2 {tool.color}">
					<tool.icon class="h-6 w-6" />
				</div>
				<h4 class="text-sm font-semibold text-white/80">{tool.title}</h4>
				<p class="mt-0.5 text-xs text-white/40">{tool.description}</p>
			</button>
		{/each}
	</div>
</div>
