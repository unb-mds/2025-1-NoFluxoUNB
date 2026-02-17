/**
 * Svelte action that dispatches a 'clickoutside' event when a click occurs outside the element.
 */
export function clickOutside(node: HTMLElement) {
	function handleClick(event: MouseEvent) {
		if (node && !node.contains(event.target as Node) && !event.defaultPrevented) {
			node.dispatchEvent(new CustomEvent('clickoutside', { detail: event }));
		}
	}

	document.addEventListener('click', handleClick, true);

	return {
		destroy() {
			document.removeEventListener('click', handleClick, true);
		}
	};
}
