import { cubicOut, cubicInOut } from 'svelte/easing';
import type { TransitionConfig } from 'svelte/transition';

export function scaleIn(
	node: Element,
	{ delay = 0, duration = 300, easing = cubicOut, start = 0.95 } = {}
): TransitionConfig {
	const style = getComputedStyle(node);
	const opacity = +style.opacity;
	const transform = style.transform === 'none' ? '' : style.transform;

	return {
		delay,
		duration,
		easing,
		css: (t) => `
			opacity: ${t * opacity};
			transform: ${transform} scale(${start + (1 - start) * t});
		`
	};
}

export function slideInRight(
	node: Element,
	{ delay = 0, duration = 300, easing = cubicOut } = {}
): TransitionConfig {
	const style = getComputedStyle(node);
	const opacity = +style.opacity;
	const width = parseFloat(style.width);

	return {
		delay,
		duration,
		easing,
		css: (t) => `
			opacity: ${t * opacity};
			transform: translateX(${(1 - t) * width}px);
		`
	};
}

export function slideInBottom(
	node: Element,
	{ delay = 0, duration = 300, easing = cubicOut } = {}
): TransitionConfig {
	const style = getComputedStyle(node);
	const opacity = +style.opacity;
	const height = parseFloat(style.height);

	return {
		delay,
		duration,
		easing,
		css: (t) => `
			opacity: ${t * opacity};
			transform: translateY(${(1 - t) * height}px);
		`
	};
}

export function float(
	_node: Element,
	{ delay = 0, duration = 600, easing = cubicInOut, y = 10 } = {}
): TransitionConfig {
	return {
		delay,
		duration,
		easing,
		css: (t) => `
			transform: translateY(${Math.sin(t * Math.PI) * y}px);
		`
	};
}

export function getStaggerDelay(index: number, baseDelay: number = 50): number {
	return index * baseDelay;
}
