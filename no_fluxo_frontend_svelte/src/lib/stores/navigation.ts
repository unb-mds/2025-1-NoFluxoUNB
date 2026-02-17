import { writable, derived, get } from 'svelte/store';
import { goto } from '$app/navigation';
import { ROUTES } from '$lib/config/routes';

// Navigation history tracking
function createNavigationStore() {
  const history = writable<string[]>([]);

  return {
    subscribe: history.subscribe,

    push(path: string) {
      history.update((h) => [...h.slice(-9), path]);
    },

    canGoBack: derived(history, ($history) => $history.length > 1),

    goBack() {
      const currentHistory = get(history);
      if (currentHistory.length > 1) {
        const previousPath = currentHistory[currentHistory.length - 2];
        history.update((h) => h.slice(0, -1));
        goto(previousPath);
      } else {
        goto(ROUTES.HOME);
      }
    },

    clear() {
      history.set([]);
    },
  };
}

export const navigationStore = createNavigationStore();

// Breadcrumb generation
export function getBreadcrumbs(pathname: string): Array<{ label: string; href: string }> {
  const segments = pathname.split('/').filter(Boolean);
  const breadcrumbs: Array<{ label: string; href: string }> = [
    { label: 'Início', href: '/' },
  ];

  let currentPath = '';
  for (const segment of segments) {
    currentPath += `/${segment}`;

    if (segment.startsWith('(') && segment.endsWith(')')) continue;

    const labels: Record<string, string> = {
      assistente: 'Assistente',
      'upload-historico': 'Importar Histórico',
      fluxogramas: 'Fluxogramas',
      'meu-fluxograma': 'Meu Fluxograma',
      login: 'Login',
      signup: 'Criar Conta',
      'password-recovery': 'Recuperar Senha',
      'login-anonimo': 'Login Anônimo',
    };

    breadcrumbs.push({
      label: labels[segment] || decodeURIComponent(segment),
      href: currentPath,
    });
  }

  return breadcrumbs;
}
