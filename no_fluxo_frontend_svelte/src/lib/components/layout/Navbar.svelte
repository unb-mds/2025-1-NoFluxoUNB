<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
	import * as Avatar from '$lib/components/ui/avatar';
	import { createSupabaseBrowserClient } from '$lib/supabase/client';
	import { authStore } from '$lib/stores/auth';
	import { ROUTES } from '$lib/config/routes';
import { Menu, X, LogOut, LayoutDashboard, Bot, Upload, GitBranch, BookOpen, GraduationCap, LifeBuoy, ShieldCheck } from 'lucide-svelte';
	import { Button } from '$lib/components/ui/button';
	import type { UserModel } from '$lib/types';

	interface Props {
		user: UserModel | null;
		isAuthenticated: boolean;
		/** Quando true, mostra Fluxogramas + Disciplinas + Assistente (sem Meu Fluxograma/Importar) e menu Visitante */
		isAnonymous?: boolean;
		/** `floating` — barra centrada na home (logo | links centro | conta). */
		variant?: 'bar' | 'floating';
	}

	let { user, isAuthenticated, isAnonymous = false, variant = 'bar' }: Props = $props();

	let mobileMenuOpen = $state(false);
	const supabase = createSupabaseBrowserClient();

	const hasHistorico = $derived(!!user?.dadosFluxograma);
	const isAdmin = $derived(!!user?.isAdmin);

	/** Links do menu: anônimo só vê Fluxogramas e Disciplinas (sem Assistente) */
	const navLinks = $derived(
		isAnonymous
			? [
					{ href: ROUTES.FLUXOGRAMAS, label: 'Fluxogramas', icon: GitBranch },
					{ href: ROUTES.DISCIPLINAS, label: 'Disciplinas', icon: BookOpen }
				]
			: [
					{ href: ROUTES.FLUXOGRAMAS, label: 'Fluxogramas', icon: GitBranch },
					hasHistorico
						? { href: ROUTES.MEU_FLUXOGRAMA, label: 'Meu Fluxograma', icon: LayoutDashboard }
						: { href: ROUTES.UPLOAD_HISTORICO, label: 'Importar Histórico', icon: Upload },
					{ href: ROUTES.PLANO_FORMATURA, label: 'Plano de Formatura', icon: GraduationCap },
					{ href: ROUTES.ASSISTENTE, label: 'Assistente', icon: Bot },
					{ href: ROUTES.DISCIPLINAS, label: 'Disciplinas', icon: BookOpen },
					{ href: ROUTES.SUPORTE, label: 'Suporte', icon: LifeBuoy },
					...(isAdmin
						? [{ href: ROUTES.ADMIN_TICKETS, label: 'Admin', icon: ShieldCheck }]
						: [])
				]
	);

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

	const navDesktopClass = $derived(
		variant === 'floating'
			? 'nav-link nav-link-premium text-[11px] font-semibold uppercase tracking-[0.08em] text-white/92 lg:text-xs'
			: 'nav-link text-sm font-medium text-foreground/90 lg:text-[15px]'
	);
</script>

<header
	class="z-50 w-full max-w-[100vw]"
	class:nf-glass-header={variant === 'bar'}
	class:nf-glass-header-floating={variant === 'floating'}
	class:navbar-floating-pill={variant === 'floating'}
	class:sticky={variant === 'bar'}
	class:top-0={variant === 'bar'}
>
	<nav
		class="nf-nav-root mx-auto flex min-h-[3rem] w-full max-w-full items-center gap-3 px-[max(0.75rem,env(safe-area-inset-left))] py-2 pt-[max(0.5rem,env(safe-area-inset-top))] pr-[max(0.75rem,env(safe-area-inset-right))] md:min-h-0 md:gap-5 md:px-8 md:py-3 md:pt-3"
	>
		<!-- Logo sans forte (identidade atual — sem brush/marker). -->
		<a
			href="/"
			class="nf-wordmark min-w-0 shrink-0"
			class:nf-wordmark--floating={variant === 'floating'}
			aria-label="NoFluxo UNB — início"
		>
			<span class="nf-wordmark-noflx">NOFLX</span><span class="nf-wordmark-unb">UNB</span>
		</a>

		{#if variant === 'floating'}
			<!-- Desktop: cluster centralizado (respiro entre itens). -->
			<div
				class="hidden min-w-0 flex-1 items-center justify-center gap-10 md:flex lg:gap-14"
				aria-label="Navegação principal"
			>
				{#if isAuthenticated}
					{#each navLinks as link}
						<a href={link.href} class="{navDesktopClass}" class:active={isActive(link.href)}>
							{link.label}
						</a>
					{/each}
				{:else}
					<a
						href={ROUTES.FLUXOGRAMAS}
						class="{navDesktopClass}"
						class:active={isActive(ROUTES.FLUXOGRAMAS)}
					>
						Fluxogramas
					</a>
					<a
						href={ROUTES.DISCIPLINAS}
						class="{navDesktopClass}"
						class:active={isActive(ROUTES.DISCIPLINAS)}
					>
						Disciplinas
					</a>
					<a href={ROUTES.LOGIN} class="{navDesktopClass}">Entrar</a>
				{/if}
			</div>

			<!-- Direita: conta ou visitante (+ menu mobile só no small). -->
			<div class="flex min-w-0 flex-1 items-center justify-end md:flex-initial md:justify-end md:gap-1">
				<div class="hidden items-center md:flex">
					{#if isAuthenticated}
						{#if isAnonymous}
							<DropdownMenu.Root>
								<DropdownMenu.Trigger>
									<Button variant="outline" size="sm" class="rounded-full border-white/14 bg-secondary/55">
										Visitante
									</Button>
								</DropdownMenu.Trigger>
								<DropdownMenu.Content class="w-56" align="end">
									<DropdownMenu.Label class="font-normal text-muted-foreground">
										Modo anônimo — algumas funções limitadas
									</DropdownMenu.Label>
									<DropdownMenu.Separator />
									<DropdownMenu.Item onclick={() => { authStore.clear(); goto(ROUTES.LOGIN); }}>
										<LogOut class="mr-2 h-4 w-4" />
										Entrar / Criar conta
									</DropdownMenu.Item>
								</DropdownMenu.Content>
							</DropdownMenu.Root>
						{:else}
							<DropdownMenu.Root>
								<DropdownMenu.Trigger>
									<button
										type="button"
										class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-full border-none bg-transparent p-0 transition-opacity hover:opacity-90"
										aria-label="Menu da conta"
									>
										<Avatar.Root class="h-10 w-10 shadow-[0_12px_40px_-4px_hsl(var(--primary)/0.52)] ring-2 ring-primary/35">
											<Avatar.Fallback class="bg-primary text-sm font-bold uppercase text-primary-foreground">
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
									{#if !hasHistorico}
										<DropdownMenu.Item onclick={() => goto(ROUTES.MEU_FLUXOGRAMA)}>
											<LayoutDashboard class="mr-2 h-4 w-4" />
											Meu Fluxograma
										</DropdownMenu.Item>
										<DropdownMenu.Separator />
									{/if}
									<DropdownMenu.Item onclick={handleLogout} class="text-destructive">
										<LogOut class="mr-2 h-4 w-4" />
										Sair
									</DropdownMenu.Item>
								</DropdownMenu.Content>
							</DropdownMenu.Root>
						{/if}
					{:else}
						<Button href={ROUTES.SIGNUP} size="sm" class="rounded-full px-6 font-semibold">
							Criar conta
						</Button>
					{/if}
				</div>
				<button
					type="button"
					class="text-foreground/90 hover:text-foreground inline-flex shrink-0 touch-manipulation items-center justify-center rounded-lg p-1.5 outline-none ring-offset-background focus-visible:ring-2 focus-visible:ring-ring/40 md:hidden"
					onclick={toggleMobileMenu}
					aria-label={mobileMenuOpen ? 'Fechar menu' : 'Abrir menu'}
				>
					{#if mobileMenuOpen}
						<X class="h-7 w-7" />
					{:else}
						<Menu class="h-7 w-7" />
					{/if}
				</button>
			</div>
		{:else}
			<!-- Demais páginas: linha única à direita. -->
			<div class="hidden items-center md:ml-auto md:flex md:gap-6 lg:gap-8">
				{#if isAuthenticated}
					{#each navLinks as link}
						<a href={link.href} class="{navDesktopClass}" class:active={isActive(link.href)}>
							{link.label}
						</a>
					{/each}
					{#if isAnonymous}
						<DropdownMenu.Root>
							<DropdownMenu.Trigger>
								<Button variant="outline" size="sm" class="rounded-full border-white/14 bg-secondary/55">
									Visitante
								</Button>
							</DropdownMenu.Trigger>
							<DropdownMenu.Content class="w-56" align="end">
								<DropdownMenu.Label class="font-normal text-muted-foreground">
									Modo anônimo — algumas funções limitadas
								</DropdownMenu.Label>
								<DropdownMenu.Separator />
								<DropdownMenu.Item onclick={() => { authStore.clear(); goto(ROUTES.LOGIN); }}>
									<LogOut class="mr-2 h-4 w-4" />
									Entrar / Criar conta
								</DropdownMenu.Item>
							</DropdownMenu.Content>
						</DropdownMenu.Root>
					{:else}
						<DropdownMenu.Root>
							<DropdownMenu.Trigger>
								<button
									type="button"
									class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-full border-none bg-transparent p-0 transition-opacity hover:opacity-90"
									aria-label="Menu da conta"
								>
									<Avatar.Root class="h-10 w-10 shadow-[0_12px_40px_-4px_hsl(var(--primary)/0.52)] ring-2 ring-primary/35">
										<Avatar.Fallback class="bg-primary text-sm font-bold uppercase text-primary-foreground">
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
								{#if !hasHistorico}
									<DropdownMenu.Item onclick={() => goto(ROUTES.MEU_FLUXOGRAMA)}>
										<LayoutDashboard class="mr-2 h-4 w-4" />
										Meu Fluxograma
									</DropdownMenu.Item>
									<DropdownMenu.Separator />
								{/if}
								<DropdownMenu.Item onclick={handleLogout} class="text-destructive">
									<LogOut class="mr-2 h-4 w-4" />
									Sair
								</DropdownMenu.Item>
							</DropdownMenu.Content>
						</DropdownMenu.Root>
					{/if}
				{:else}
					<a
						href={ROUTES.FLUXOGRAMAS}
						class="{navDesktopClass}"
						class:active={isActive(ROUTES.FLUXOGRAMAS)}
					>
						Fluxogramas
					</a>
					<a
						href={ROUTES.DISCIPLINAS}
						class="{navDesktopClass}"
						class:active={isActive(ROUTES.DISCIPLINAS)}
					>
						Disciplinas
					</a>
					<a href={ROUTES.LOGIN} class="{navDesktopClass}">Entrar</a>
					<Button href={ROUTES.SIGNUP} size="sm" class="ml-1 rounded-full px-6 font-semibold">
						Criar conta
					</Button>
				{/if}
			</div>
			<button
				type="button"
				class="text-foreground/90 hover:text-foreground ml-auto inline-flex shrink-0 touch-manipulation items-center justify-center rounded-lg p-1.5 outline-none ring-offset-background focus-visible:ring-2 focus-visible:ring-ring/40 md:hidden"
				onclick={toggleMobileMenu}
				aria-label={mobileMenuOpen ? 'Fechar menu' : 'Abrir menu'}
			>
				{#if mobileMenuOpen}
					<X class="h-7 w-7" />
				{:else}
					<Menu class="h-7 w-7" />
				{/if}
			</button>
		{/if}
	</nav>
</header>

<!-- Mobile Drawer Portal (outside header to avoid stacking context issues) -->
{#if mobileMenuOpen}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="fixed inset-0 z-[9998] bg-black/50 backdrop-blur-[2px]"
		onclick={closeMobileMenu}
		onkeydown={(e) => e.key === 'Escape' && closeMobileMenu()}
		role="button"
		tabindex="-1"
		aria-label="Fechar menu"
	></div>
	<div class="mobile-drawer-portal">
		<div class="flex flex-col gap-1 p-4">
			<div class="mb-2 flex items-center justify-between">
				<span class="text-sm font-medium text-muted-foreground">Menu</span>
				<button
					type="button"
					class="mobile-close-btn"
					onclick={closeMobileMenu}
					aria-label="Fechar menu"
				>
					<X class="h-5 w-5" />
				</button>
			</div>
			{#if isAuthenticated}
				<!-- User info ou Visitante -->
				<div class="mb-4 border-b border-white/10 pb-4">
					{#if isAnonymous}
						<p class="text-lg font-semibold text-foreground">Visitante</p>
						<p class="text-sm text-muted-foreground">Modo anônimo</p>
					{:else}
						<p class="text-lg font-semibold text-foreground">{user?.nomeCompleto || 'Usuário'}</p>
						<p class="text-sm text-muted-foreground">{user?.email}</p>
					{/if}
				</div>

				{#each navLinks as link}
					{@const Icon = link.icon}
					<a
						href={link.href}
						class="mobile-nav-item"
						class:active={isActive(link.href)}
						onclick={closeMobileMenu}
					>
						<Icon class="h-5 w-5" />
						<span>{link.label}</span>
					</a>
				{/each}

				{#if !isAnonymous && !hasHistorico}
					<a
						href={ROUTES.MEU_FLUXOGRAMA}
						class="mobile-nav-item"
						onclick={closeMobileMenu}
					>
						<LayoutDashboard class="h-5 w-5" />
						<span>Meu Fluxograma</span>
					</a>
				{/if}

				<hr class="my-3 border-white/10" />

				{#if isAnonymous}
					<button
						onclick={() => { authStore.clear(); closeMobileMenu(); goto(ROUTES.LOGIN); }}
						class="mobile-nav-item text-amber-400"
					>
						<LogOut class="h-5 w-5" />
						<span>Entrar / Criar conta</span>
					</button>
				{:else}
					<button
						onclick={() => { handleLogout(); closeMobileMenu(); }}
						class="mobile-nav-item text-red-400"
					>
						<LogOut class="h-5 w-5" />
						<span>Sair</span>
					</button>
				{/if}
			{:else}
				<a
					href={ROUTES.FLUXOGRAMAS}
					class="mobile-nav-item"
					class:active={isActive(ROUTES.FLUXOGRAMAS)}
					onclick={closeMobileMenu}
				>
					<GitBranch class="h-5 w-5" />
					<span>Fluxogramas</span>
				</a>
				<a
					href={ROUTES.DISCIPLINAS}
					class="mobile-nav-item"
					class:active={isActive(ROUTES.DISCIPLINAS)}
					onclick={closeMobileMenu}
				>
					<BookOpen class="h-5 w-5" />
					<span>Disciplinas</span>
				</a>
				<hr class="my-3 border-white/10" />
				<a href={ROUTES.LOGIN} class="mobile-nav-item" onclick={closeMobileMenu}>
					Entrar
				</a>
				<Button
					href={ROUTES.SIGNUP}
					class="mt-2 w-full rounded-full"
					onclick={closeMobileMenu}
				>
					Criar conta
				</Button>
			{/if}
		</div>

		<div class="mt-auto border-t border-white/10 p-4 text-center text-xs text-muted-foreground">
			NoFluxo UNB © {new Date().getFullYear()}
		</div>
	</div>
{/if}

<style>
	/* Floating home navbar — pílula com vidro, borda e glow */
	header.navbar-floating-pill {
		background: hsl(var(--background) / 0.75);
		backdrop-filter: blur(18px) saturate(1.5);
		-webkit-backdrop-filter: blur(18px) saturate(1.5);
		border: 1px solid hsl(var(--border) / 0.9);
		border-radius: 999px;
		padding: 12px 28px;
		box-shadow:
			0 0 0 1px hsl(var(--primary) / 0.12),
			0 8px 32px hsl(0 0% 0% / 0.4);
	}

	:global(.nf-wordmark--floating .nf-wordmark-noflx),
	:global(.nf-wordmark--floating .nf-wordmark-unb) {
		font-size: 1.32rem;
	}

	@media (min-width: 768px) {
		:global(.nf-wordmark--floating .nf-wordmark-noflx),
		:global(.nf-wordmark--floating .nf-wordmark-unb) {
			font-size: 1.52rem;
		}
	}

	/* Mobile drawer - slides from right */
	.mobile-drawer-portal {
		position: fixed;
		top: 0;
		right: 0;
		bottom: 0;
		width: min(300px, 88vw);
		max-width: 100vw;
		z-index: 9999;
		display: flex;
		flex-direction: column;
		padding-bottom: env(safe-area-inset-bottom, 0px);
		padding-top: env(safe-area-inset-top, 0px);
		background: hsl(var(--card) / 0.97);
		border-left: 1px solid hsl(0 0% 100% / 0.08);
		box-shadow: -16px 0 48px hsl(0 0% 0% / 0.4);
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
		padding: 12px 14px;
		border-radius: 10px;
		color: hsl(var(--foreground));
		font-weight: 500;
		text-decoration: none;
		transition: background 160ms ease;
		border: none;
		background: none;
		width: 100%;
		text-align: left;
		cursor: pointer;
		font-size: 15px;
	}

	.mobile-nav-item:hover {
		background: hsl(0 0% 100% / 0.06);
	}

	.mobile-nav-item.active {
		background: hsl(var(--secondary) / 0.85);
		border-left: 3px solid hsl(var(--primary));
		padding-left: 11px;
	}

	.mobile-close-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		height: 36px;
		width: 36px;
		border-radius: 9999px;
		border: none;
		background: hsl(0 0% 100% / 0.06);
		color: hsl(var(--muted-foreground));
		cursor: pointer;
		transition:
			background 0.15s ease,
			color 0.15s ease;
	}

	.mobile-close-btn:hover {
		background: hsl(0 0% 100% / 0.1);
		color: hsl(var(--foreground));
	}
</style>
