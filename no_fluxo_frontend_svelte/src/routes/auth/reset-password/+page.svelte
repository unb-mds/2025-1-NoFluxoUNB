<script lang="ts">
	import { authService } from '$lib/services/auth.service';
	import { goto } from '$app/navigation';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import { AlertTriangle, CheckCircle, Eye, EyeOff } from 'lucide-svelte';

	let newPassword = $state('');
	let confirmPassword = $state('');
	let localError = $state('');
	let submitting = $state(false);
	let success = $state(false);
	let showPassword = $state(false);
	let showConfirm = $state(false);

	async function handleSubmit(e: SubmitEvent) {
		e.preventDefault();

		if (!newPassword || !confirmPassword) {
			localError = 'Preencha todos os campos';
			return;
		}

		if (newPassword !== confirmPassword) {
			localError = 'As senhas não coincidem';
			return;
		}

		if (newPassword.length < 6) {
			localError = 'A senha deve ter pelo menos 6 caracteres';
			return;
		}

		submitting = true;
		localError = '';

		const result = await authService.updatePassword(newPassword);

		if (result.success) {
			success = true;
			setTimeout(() => {
				goto('/login');
			}, 3000);
		} else {
			localError = result.error || 'Erro ao atualizar senha';
		}

		submitting = false;
	}
</script>

<svelte:head>
	<title>Redefinir Senha - NoFluxo UNB</title>
</svelte:head>

<AnimatedBackground />

<div class="relative z-10 flex min-h-screen items-center justify-center px-4">
	<div class="auth-card">
		<form onsubmit={handleSubmit}>
			<h2>Redefinir Senha</h2>

			{#if success}
				<div class="auth-success">
					<CheckCircle class="h-5 w-5 shrink-0 text-emerald-600" />
					<span>Senha atualizada com sucesso! Redirecionando para o login...</span>
				</div>
			{:else}
				{#if localError}
					<div class="auth-error">
						<AlertTriangle class="h-5 w-5 shrink-0 text-amber-600" />
						<span>{localError}</span>
					</div>
				{/if}

				<div class="form-group">
					<label for="newPassword">Nova Senha</label>
					<div class="password-wrapper">
						<input
							type={showPassword ? 'text' : 'password'}
							id="newPassword"
							class="auth-input"
							bind:value={newPassword}
							placeholder="Mínimo 6 caracteres"
							disabled={submitting}
							required
						/>
						<button type="button" class="password-toggle" onclick={() => showPassword = !showPassword} tabindex="-1">
							{#if showPassword}<EyeOff class="h-5 w-5 text-gray-400" />{:else}<Eye class="h-5 w-5 text-gray-400" />{/if}
						</button>
					</div>
				</div>

				<div class="form-group">
					<label for="confirmPassword">Confirmar Nova Senha</label>
					<div class="password-wrapper">
						<input
							type={showConfirm ? 'text' : 'password'}
							id="confirmPassword"
							class="auth-input"
							bind:value={confirmPassword}
							placeholder="Repita a nova senha"
							disabled={submitting}
							required
						/>
						<button type="button" class="password-toggle" onclick={() => showConfirm = !showConfirm} tabindex="-1">
							{#if showConfirm}<EyeOff class="h-5 w-5 text-gray-400" />{:else}<Eye class="h-5 w-5 text-gray-400" />{/if}
						</button>
					</div>
				</div>

				<button type="submit" class="auth-btn" disabled={submitting}>
					{#if submitting}
						Atualizando...
					{:else}
						Atualizar Senha
					{/if}
				</button>
			{/if}
		</form>
	</div>
</div>

<style>
	form {
		width: 100%;
	}

	h2 {
		text-align: center;
		margin-bottom: 1.5rem;
		color: #2563eb;
		font-size: 28px;
		font-weight: 700;
	}

	.form-group {
		margin-bottom: 1rem;
	}

	label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 500;
		font-size: 14px;
		color: #374151;
	}

	.password-wrapper {
		position: relative;
	}

	.password-toggle {
		position: absolute;
		right: 14px;
		top: 50%;
		transform: translateY(-50%);
		background: none;
		border: none;
		cursor: pointer;
		padding: 4px;
	}
</style>
