<script lang="ts">
	import { page } from '$app/stores';
	import { ROUTES } from '$lib/config/routes';
	import { LayoutDashboard, Ticket, Settings } from 'lucide-svelte';

	const links = [
		{ href: ROUTES.ADMIN_DASHBOARD, label: 'Dashboard', icon: LayoutDashboard },
		{ href: ROUTES.ADMIN_TICKETS, label: 'Tickets', icon: Ticket },
		{ href: ROUTES.ADMIN_CONFIGURACOES, label: 'Configurações', icon: Settings }
	];

	let active = $derived((href: string) => $page.url.pathname.startsWith(href));
</script>

<nav class="admin-nav">
	{#each links as l}
		{@const Icon = l.icon}
		<a href={l.href} class="admin-nav-link" class:active={active(l.href)}>
			<Icon class="h-4 w-4" />
			<span>{l.label}</span>
		</a>
	{/each}
</nav>

<style>
	.admin-nav {
		display: flex;
		gap: 6px;
		padding: 4px;
		border-radius: 10px;
		background: hsl(var(--muted) / 0.4);
		border: 1px solid hsl(var(--border));
		width: fit-content;
	}
	.admin-nav-link {
		display: inline-flex;
		align-items: center;
		gap: 7px;
		padding: 7px 14px;
		border-radius: 7px;
		font-size: 13px;
		font-weight: 600;
		color: hsl(var(--muted-foreground));
		text-decoration: none;
		transition: all 120ms;
	}
	.admin-nav-link:hover {
		color: hsl(var(--foreground));
		background: hsl(var(--muted) / 0.6);
	}
	.admin-nav-link.active {
		color: hsl(var(--primary-foreground));
		background: hsl(var(--primary));
	}
</style>
