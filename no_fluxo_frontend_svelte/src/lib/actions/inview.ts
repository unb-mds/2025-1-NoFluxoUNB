export interface InViewOptions {
	root?: Element | null;
	rootMargin?: string;
	threshold?: number | number[];
	once?: boolean;
	onInView?: () => void;
	onOutView?: () => void;
}

export function inview(node: HTMLElement, options: InViewOptions = {}) {
	const { once = true, rootMargin = '0px', threshold = 0.1, onInView, onOutView } = options;

	const observer = new IntersectionObserver(
		(entries) => {
			entries.forEach((entry) => {
				if (entry.isIntersecting) {
					onInView?.();
					if (once) {
						observer.unobserve(node);
					}
				} else if (!once) {
					onOutView?.();
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
