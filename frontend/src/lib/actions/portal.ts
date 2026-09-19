import type { Action } from 'svelte/action';

/**
 * Move o nó para o final de `document.body` (ou outro alvo), para fugir de
 * `transform` / `backdrop-filter` nos ancestrais que quebram `position: fixed`
 * e empilhamento (ex.: modais sobre o fluxograma).
 */
export const portal: Action<HTMLElement, HTMLElement | string | undefined> = (node, target) => {
	if (typeof document === 'undefined') {
		return { destroy() {} };
	}

	const targetEl =
		typeof target === 'string'
			? (document.querySelector(target) as HTMLElement | null)
			: target ?? document.body;

	(targetEl ?? document.body).appendChild(node);

	return {
		destroy() {
			node.parentNode?.removeChild(node);
		}
	};
};
