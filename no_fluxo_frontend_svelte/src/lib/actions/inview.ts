export interface InViewOptions {
	root?: Element | null;
	rootMargin?: string;
	threshold?: number | number[];
	once?: boolean;
}

export function inview(node: HTMLElement, options: InViewOptions = {}) {
	const { once = true, rootMargin = '0px', threshold = 0.1 } = options;

	const observer = new IntersectionObserver(
		(entries) => {
			entries.forEach((entry) => {
				if (entry.isIntersecting) {
					node.dispatchEvent(new CustomEvent('inview'));
					if (once) {
						observer.unobserve(node);
					}
				} else if (!once) {
					node.dispatchEvent(new CustomEvent('outview'));
				}
			});
		},
		{ rootMargin, threshold }
	);

	observer.observe(node);

	return {
		destroy() {
			observer.unobserve(node);
		}
	};
}
