<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { Button } from '$lib/components/ui/button';
	import { Home, ArrowLeft, RefreshCw } from 'lucide-svelte';

	let error = $derived($page.error);
	let status = $derived($page.status);

	function goBack() {
		history.back();
	}

	function retry() {
		location.reload();
	}

	const errorMessages: Record<number, { title: string; description: string }> = {
		404: {
			title: 'Página não encontrada',
			description: 'A página que você está procurando não existe ou foi movida.',
		},
		401: {
			title: 'Não autorizado',
			description: 'Você precisa estar logado para acessar esta página.',
		},
		403: {
			title: 'Acesso negado',
			description: 'Você não tem permissão para acessar esta página.',
		},
		500: {
			title: 'Erro interno do servidor',
			description: 'Algo deu errado. Por favor, tente novamente mais tarde.',
		},
	};

	let errorInfo = $derived(
		errorMessages[status] || {
			title: 'Algo deu errado',
			description: error?.message || 'Ocorreu um erro inesperado.',
		}
	);
</script>

<svelte:head>
	<title>{status} - {errorInfo.title} | NoFluxo UNB</title>
</svelte:head>

<div class="flex min-h-[60vh] items-center justify-center px-4">
	<div class="text-center">
		<div class="mx-auto mb-6 flex h-24 w-24 items-center justify-center rounded-full bg-destructive/10">
			<span class="text-4xl font-bold text-destructive">{status}</span>
		</div>

		<h1 class="mb-2 text-2xl font-bold">{errorInfo.title}</h1>
		<p class="mb-8 max-w-md text-muted-foreground">
			{errorInfo.description}
		</p>

		<div class="flex flex-wrap justify-center gap-3">
			<Button variant="outline" onclick={goBack}>
				<ArrowLeft class="mr-2 h-4 w-4" />
				Voltar
			</Button>
			<Button onclick={() => goto('/')}>
				<Home class="mr-2 h-4 w-4" />
				Ir para o início
			</Button>
			{#if status >= 500}
				<Button variant="secondary" onclick={retry}>
					<RefreshCw class="mr-2 h-4 w-4" />
					Tentar novamente
				</Button>
			{/if}
		</div>
	</div>
</div>
