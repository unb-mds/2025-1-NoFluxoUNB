<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
	import * as Avatar from '$lib/components/ui/avatar';
	import { createSupabaseBrowserClient } from '$lib/supabase/client';
	import { authStore } from '$lib/stores/auth';
	import { ROUTES } from '$lib/config/routes';
	import { Menu, X, LogOut, LayoutDashboard, Bot, Upload, GitBranch } from 'lucide-svelte';
	import type { UserModel } from '$lib/types';

	interface Props {
		user: UserModel | null;
		isAuthenticated: boolean;
	}

	let { user, isAuthenticated }: Props = $props();

	let mobileMenuOpen = $state(false);
	const supabase = createSupabaseBrowserClient();

	const navLinks = [
		{ href: ROUTES.FLUXOGRAMAS, label: 'Fluxogramas', icon: GitBranch },
		{ href: ROUTES.ASSISTENTE, label: 'Assistente', icon: Bot },
		{ href: ROUTES.UPLOAD_HISTORICO, label: 'Importar Histórico', icon: Upload },
	];

	async function handleLogout() {
		await supabase.auth.signOut();
		authStore.clear();
		goto(ROUTES.LOGIN);
	}

	function toggleMobileMenu() {
		mobileMenuOpen = !mobileMenuOpen;
	}

	function closeMobileMenu() {
		mobileMenuOpen = false;
	}

	let isActive = $derived((href: string) => $page.url.pathname === href || $page.url.pathname.startsWith(href + '/'));
</script>

<header class="navbar-glass sticky top-0 z-50 w-full">
	<nav class="mx-auto flex items-center justify-between px-4 py-2 md:px-8 md:py-3">
		<!-- Logo -->
		<a href="/" class="logo text-shadow">
			NOFLX UNB
		</a>

		<!-- Desktop Navigation -->
		<div class="hidden items-center gap-6 md:flex lg:gap-8">
			{#if isAuthenticated}
				{#each navLinks as link}
					<a
						href={link.href}
						class="nav-link font-marker text-sm font-bold text-white lg:text-base"
						class:active={isActive(link.href)}
					>
						{link.label}
					</a>
				{/each}

				<!-- User Menu -->
				<DropdownMenu.Root>
					<DropdownMenu.Trigger>
						<button class="relative flex h-10 w-10 items-center justify-center rounded-full bg-white/10 transition-colors hover:bg-white/20">
							<Avatar.Root class="h-10 w-10">
								<Avatar.Fallback class="bg-nofluxo-primary text-white font-bold">
									{user?.nomeCompleto?.charAt(0).toUpperCase() || 'U'}
								</Avatar.Fallback>
							</Avatar.Root>
						</button>
					</DropdownMenu.Trigger>
					<DropdownMenu.Content class="w-56" align="end">
						<DropdownMenu.Label class="font-normal">
							<div class="flex flex-col space-y-1">
								<p class="text-sm font-medium leading-none">{user?.nomeCompleto || 'Usuário'}</p>
								<p class="text-xs leading-none text-muted-foreground">{user?.email}</p>
							</div>
						</DropdownMenu.Label>
						<DropdownMenu.Separator />
						<DropdownMenu.Item onclick={() => goto(ROUTES.MEU_FLUXOGRAMA)}>
							<LayoutDashboard class="mr-2 h-4 w-4" />
							Meu Fluxograma
						</DropdownMenu.Item>
						<DropdownMenu.Separator />
						<DropdownMenu.Item onclick={handleLogout} class="text-destructive">
							<LogOut class="mr-2 h-4 w-4" />
							Sair
						</DropdownMenu.Item>
					</DropdownMenu.Content>
				</DropdownMenu.Root>
			{:else}
				<a href={ROUTES.LOGIN} class="nav-link font-marker text-sm font-bold text-white lg:text-base">
					Entrar
				</a>
				<a
					href={ROUTES.SIGNUP}
					class="rounded-full bg-gradient-to-r from-purple-500 to-pink-500 px-5 py-2 font-marker text-sm font-bold text-white transition-transform hover:scale-105"
				>
					Criar Conta
				</a>
			{/if}
		</div>

		<!-- Mobile Menu Button -->
		<button
			class="text-white md:hidden"
			onclick={toggleMobileMenu}
			aria-label={mobileMenuOpen ? 'Fechar menu' : 'Abrir menu'}
		>
			{#if mobileMenuOpen}
				<X class="h-7 w-7" />
			{:else}
				<Menu class="h-7 w-7" />
			{/if}
		</button>
	</nav>
</header>

<!-- Mobile Drawer Portal (outside header to avoid stacking context issues) -->
{#if mobileMenuOpen}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="fixed inset-0 z-[9998] bg-black/60 backdrop-blur-sm"
		onclick={closeMobileMenu}
		onkeydown={(e) => e.key === 'Escape' && closeMobileMenu()}
		role="button"
		tabindex="-1"
		aria-label="Fechar menu"
	></div>
	<div class="mobile-drawer-portal">
		<div class="flex flex-col gap-1 p-4">
			{#if isAuthenticated}
				<!-- User info -->
				<div class="mb-4 border-b border-white/10 pb-4">
					<p class="font-marker text-lg text-white">{user?.nomeCompleto || 'Usuário'}</p>
					<p class="text-sm text-white/60">{user?.email}</p>
				</div>

				{#each navLinks as link}
					<a
						href={link.href}
						class="mobile-nav-item"
						class:active={isActive(link.href)}
						onclick={closeMobileMenu}
					>
						<svelte:component this={link.icon} class="h-5 w-5" />
						<span>{link.label}</span>
					</a>
				{/each}

				<a
					href={ROUTES.MEU_FLUXOGRAMA}
					class="mobile-nav-item"
					onclick={closeMobileMenu}
				>
					<LayoutDashboard class="h-5 w-5" />
					<span>Meu Fluxograma</span>
				</a>

				<hr class="my-3 border-white/10" />

				<button
					onclick={() => { handleLogout(); closeMobileMenu(); }}
					class="mobile-nav-item text-red-400"
				>
					<LogOut class="h-5 w-5" />
					<span>Sair</span>
				</button>
			{:else}
				<a href={ROUTES.LOGIN} class="mobile-nav-item" onclick={closeMobileMenu}>
					Entrar
				</a>
				<a
					href={ROUTES.SIGNUP}
					class="mt-2 block rounded-full bg-gradient-to-r from-purple-500 to-pink-500 px-5 py-3 text-center font-marker font-bold text-white"
					onclick={closeMobileMenu}
				>
					Criar Conta
				</a>
			{/if}
		</div>

		<div class="mt-auto border-t border-white/10 p-4 text-center text-sm text-white/40">
			NoFluxoUNB © {new Date().getFullYear()}
		</div>
	</div>
{/if}

<style>
	.navbar-glass {
		backdrop-filter: blur(4px);
		-webkit-backdrop-filter: blur(4px);
		background: rgba(0, 0, 0, 0.3);
	}

	.logo {
		font-family: 'Permanent Marker', cursive;
		color: white;
		font-size: 20px;
		text-decoration: none;
	}

	@media (min-width: 768px) {
		.logo {
			font-size: 28px;
		}
	}

	@media (min-width: 1024px) {
		.logo {
			font-size: 36px;
		}
	}

	/* Mobile drawer - slides from right */
	.mobile-drawer-portal {
		position: fixed;
		top: 0;
		right: 0;
		bottom: 0;
		width: 280px;
		z-index: 9999;
		display: flex;
		flex-direction: column;
		background: linear-gradient(180deg, #0a0a0a 0%, #1a0a2e 100%);
		animation: slideIn 200ms ease-out;
	}

	@keyframes slideIn {
		from {
			transform: translateX(100%);
		}
		to {
			transform: translateX(0);
		}
	}

	.mobile-nav-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px 16px;
		border-radius: 8px;
		color: white;
		font-weight: 500;
		text-decoration: none;
		transition: background 200ms;
		border: none;
		background: none;
		width: 100%;
		text-align: left;
		cursor: pointer;
		font-size: 15px;
	}

	.mobile-nav-item:hover {
		background: rgba(255, 255, 255, 0.08);
	}

	.mobile-nav-item.active {
		background: rgba(255, 255, 255, 0.08);
		border-left: 3px solid #9333ea;
	}
</style>
