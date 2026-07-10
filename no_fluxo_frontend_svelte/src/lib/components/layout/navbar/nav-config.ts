// no_fluxo_frontend_svelte/src/lib/components/layout/navbar/nav-config.ts
import { LayoutDashboard, Bot, Upload, GitBranch, BookOpen, GraduationCap } from 'lucide-svelte';
import { ROUTES } from '$lib/config/routes';

/** Tipo de um ícone lucide-svelte (componente Svelte). */
export type NavIcon = typeof GitBranch;

export interface NavChild {
	href: string;
	label: string;
	icon: NavIcon;
}

export type NavEntry =
	| { kind: 'link'; href: string; label: string; icon: NavIcon }
	| { kind: 'group'; label: string; children: NavChild[] };

/**
 * Monta a lista de navegação para usuário autenticado.
 * Anônimo: só Fluxogramas + Disciplinas (não pode planejar).
 * Suporte fica fora (FAB). Admin não entra aqui (vai no menu da conta).
 */
export function buildNavEntries(args: { isAnonymous: boolean; hasHistorico: boolean }): NavEntry[] {
	const { isAnonymous, hasHistorico } = args;

	if (isAnonymous) {
		return [
			{ kind: 'link', href: ROUTES.FLUXOGRAMAS, label: 'Fluxogramas', icon: GitBranch },
			{ kind: 'link', href: ROUTES.DISCIPLINAS, label: 'Disciplinas', icon: BookOpen }
		];
	}

	return [
		{ kind: 'link', href: ROUTES.FLUXOGRAMAS, label: 'Fluxogramas', icon: GitBranch },
		hasHistorico
			? { kind: 'link', href: ROUTES.MEU_FLUXOGRAMA, label: 'Meu Fluxograma', icon: LayoutDashboard }
			: { kind: 'link', href: ROUTES.UPLOAD_HISTORICO, label: 'Importar Histórico', icon: Upload },
		{
			kind: 'group',
			label: 'Planejamento',
			children: [
				{ href: ROUTES.PLANO_FORMATURA, label: 'Plano de Formatura', icon: GraduationCap },
				{ href: ROUTES.ASSISTENTE, label: 'Assistente IA', icon: Bot }
			]
		},
		{ kind: 'link', href: ROUTES.DISCIPLINAS, label: 'Disciplinas', icon: BookOpen }
	];
}

/** Link ativo se rota igual ou for prefixo (ex.: /meu-fluxograma/ADS). */
export function isLinkActive(href: string, pathname: string): boolean {
	return pathname === href || pathname.startsWith(href + '/');
}

/** Grupo ativo se qualquer filho estiver ativo. */
export function isEntryActive(entry: NavEntry, pathname: string): boolean {
	if (entry.kind === 'link') return isLinkActive(entry.href, pathname);
	return entry.children.some((child) => isLinkActive(child.href, pathname));
}
