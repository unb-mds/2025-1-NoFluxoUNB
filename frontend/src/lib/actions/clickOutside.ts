export interface ClickOutsideOptions {
	onClickOutside?: (event: MouseEvent) => void;
}

/**
 * Svelte action that calls a callback when a click occurs outside the element.
 */
export function clickOutside(node: HTMLElement, options: ClickOutsideOptions = {}) {
	let { onClickOutside } = options;

	function handleClick(event: MouseEvent) {
		if (node && !node.contains(event.target as Node) && !event.defaultPrevented) {
			onClickOutside?.(event);
		}
	}

	document.addEventListener('click', handleClick, true);

	return {
		update(newOptions: ClickOutsideOptions) {
			onClickOutside = newOptions.onClickOutside;
		},
		destroy() {
			document.removeEventListener('click', handleClick, true);
		}
	};
}
