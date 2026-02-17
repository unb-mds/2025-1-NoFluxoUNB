<script lang="ts">
	import { authService } from '$lib/services/auth.service';
	import { goto } from '$app/navigation';
	import { CheckCircle, XCircle, ArrowLeft, Eye, FileX, Upload } from 'lucide-svelte';

	let showSuccess = $state(false);

	function handleAnonymousLogin() {
		showSuccess = true;
		authService.setAnonymous();

		setTimeout(() => {
			goto('/fluxogramas');
		}, 2000);
	}
</script>

<div class="w-full max-w-[440px] mx-auto">
	{#if showSuccess}
		<div class="auth-card flex flex-col items-center gap-4 py-8">
			<div class="flex h-16 w-16 items-center justify-center rounded-full bg-emerald-100">
				<CheckCircle class="h-10 w-10 text-emerald-500" />
			</div>
			<h3 class="text-xl font-semibold text-gray-800">Login anônimo</h3>
			<p class="text-center text-gray-500">Você entrou como usuário anônimo. Redirecionando...</p>
		</div>
	{:else}
		<div class="auth-card">
			<h2 class="mb-2 text-center text-[28px] font-bold text-blue-600">Entrar sem conta</h2>
			<p class="mb-6 text-center text-[0.95rem] leading-relaxed text-gray-500">
				Você pode explorar os fluxogramas sem criar uma conta. Algumas funcionalidades estarão limitadas.
			</p>

			<div class="mb-6 rounded-xl bg-gray-50 px-5 py-4">
				<!-- Available -->
				<div class="flex items-center gap-3 py-2.5">
					<div class="flex h-7 w-7 items-center justify-center rounded-full bg-emerald-100">
						<Eye class="h-4 w-4 text-emerald-600" />
					</div>
					<span class="text-[0.95rem] text-gray-700">Visualizar fluxogramas de cursos</span>
				</div>

				<div class="my-1 h-px bg-gray-200"></div>

				<!-- Unavailable -->
				<div class="flex items-center gap-3 py-2.5 opacity-60">
					<div class="flex h-7 w-7 items-center justify-center rounded-full bg-red-100">
						<XCircle class="h-4 w-4 text-red-500" />
					</div>
					<span class="text-[0.95rem] text-gray-400">Salvar seu progresso</span>
				</div>

				<div class="my-1 h-px bg-gray-200"></div>

				<div class="flex items-center gap-3 py-2.5 opacity-60">
					<div class="flex h-7 w-7 items-center justify-center rounded-full bg-red-100">
						<Upload class="h-4 w-4 text-red-500" />
					</div>
					<span class="text-[0.95rem] text-gray-400">Importar histórico acadêmico</span>
				</div>
			</div>

			<button class="auth-btn-visitor" onclick={handleAnonymousLogin}>
				Continuar sem conta
			</button>

			<div class="mt-5 text-center">
				<a href="/login" class="auth-link flex items-center justify-center gap-1.5 text-sm">
					<ArrowLeft class="h-4 w-4" />
					Voltar para login
				</a>
			</div>
		</div>
	{/if}
</div>
