<script lang="ts">
	import { ROUTES } from '$lib/config/routes';
	import { LayoutDashboard, Bot, Upload, GitBranch } from 'lucide-svelte';
	import type { UserModel } from '$lib/types';

	interface NavItem {
		href: string;
		label: string;
		icon: typeof GitBranch;
	}

	interface NavGroup {
		title: string;
		items: NavItem[];
	}

	interface Props {
		user: UserModel | null;
		currentPath: string;
		onNavigate?: () => void;
	}

	let { user, currentPath, onNavigate }: Props = $props();

	const navItems: NavGroup[] = [
		{
			title: 'Dashboard',
			items: [
				{ href: ROUTES.FLUXOGRAMAS, label: 'Fluxogramas', icon: GitBranch },
				{ href: ROUTES.MEU_FLUXOGRAMA, label: 'Meu Fluxograma', icon: LayoutDashboard },
			],
		},
		{
			title: 'Ferramentas',
			items: [
				{ href: ROUTES.UPLOAD_HISTORICO, label: 'Importar Histórico', icon: Upload },
				{ href: ROUTES.ASSISTENTE, label: 'Assistente IA', icon: Bot },
			],
		},
	];

	function isActive(href: string): boolean {
		return currentPath === href || currentPath.startsWith(href + '/');
	}
</script>

<div class="flex h-full flex-col">
	<!-- Logo -->
	<div class="flex h-16 items-center border-b px-6">
		<a href="/" class="flex items-center space-x-2" onclick={onNavigate}>
			<span class="text-lg font-bold text-primary">NoFluxo</span>
		</a>
	</div>

	<!-- Navigation -->
	<nav class="flex-1 overflow-y-auto p-4">
		{#each navItems as group}
			<div class="mb-6">
				<h3 class="mb-2 px-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
					{group.title}
				</h3>
				<ul class="space-y-1">
					{#each group.items as item}
						<li>
							<a
								href={item.href}
								class="flex items-center rounded-lg px-3 py-2 text-sm font-medium transition-colors {isActive(item.href) ? 'bg-primary/10 text-primary' : 'text-muted-foreground hover:bg-accent hover:text-accent-foreground'}"
								onclick={onNavigate}
							>
								<item.icon class="mr-3 h-5 w-5" />
								{item.label}
							</a>
						</li>
					{/each}
				</ul>
			</div>
		{/each}
	</nav>

	<!-- User Info -->
	{#if user}
		<div class="border-t p-4">
			<div class="flex items-center space-x-3">
				<div class="flex h-10 w-10 items-center justify-center rounded-full bg-primary/10 text-primary">
					{user.nomeCompleto?.charAt(0).toUpperCase() || 'U'}
				</div>
				<div class="flex-1 truncate">
					<p class="truncate text-sm font-medium">{user.nomeCompleto}</p>
					<p class="truncate text-xs text-muted-foreground">{user.email}</p>
				</div>
			</div>
		</div>
	{/if}
</div>
