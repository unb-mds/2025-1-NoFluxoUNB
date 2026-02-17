/**
 * Screenshot utility — captures a DOM element as a PNG image and triggers download.
 * Uses the native Canvas API with foreignObject SVG approach as a lightweight
 * fallback when html2canvas is not available.
 */

export async function captureScreenshot(
	element: HTMLElement,
	filename = 'fluxograma.png'
): Promise<void> {
	try {
		// Try html2canvas first (if available)
		let html2canvas: ((el: HTMLElement, opts: Record<string, unknown>) => Promise<HTMLCanvasElement>) | null = null;
		try {
			// eslint-disable-next-line @typescript-eslint/no-explicit-any
			const mod = await (Function('return import("html2canvas")')()) as any;
			html2canvas = mod.default ?? mod;
		} catch {
			// html2canvas not installed — fall through to SVG approach
		}

		if (html2canvas) {
			const canvas = await html2canvas(element, {
				backgroundColor: '#0a0a0a',
				scale: 2,
				useCORS: true,
				logging: false
			});
			downloadCanvas(canvas, filename);
			return;
		}

		// Fallback: use native SVG foreignObject approach
		await captureWithSvgForeignObject(element, filename);
	} catch (error) {
		console.error('Screenshot failed:', error);
		throw new Error('Não foi possível capturar a imagem do fluxograma.');
	}
}

async function captureWithSvgForeignObject(
	element: HTMLElement,
	filename: string
): Promise<void> {
	const rect = element.getBoundingClientRect();
	const width = rect.width;
	const height = rect.height;

	// Clone the element
	const clone = element.cloneNode(true) as HTMLElement;

	// Collect computed styles
	const styles = getComputedStyle(element);
	clone.style.width = `${width}px`;
	clone.style.height = `${height}px`;
	clone.style.overflow = 'visible';
	clone.style.background = styles.background || '#0a0a0a';

	// Build SVG with foreignObject
	const svgData = `
		<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">
			<foreignObject width="100%" height="100%">
				<div xmlns="http://www.w3.org/1999/xhtml">
					${clone.outerHTML}
				</div>
			</foreignObject>
		</svg>
	`;

	const svgBlob = new Blob([svgData], { type: 'image/svg+xml;charset=utf-8' });
	const url = URL.createObjectURL(svgBlob);

	const img = new Image();
	img.onload = () => {
		const canvas = document.createElement('canvas');
		canvas.width = width * 2;
		canvas.height = height * 2;
		const ctx = canvas.getContext('2d')!;
		ctx.scale(2, 2);
		ctx.drawImage(img, 0, 0);
		URL.revokeObjectURL(url);
		downloadCanvas(canvas, filename);
	};
	img.onerror = () => {
		URL.revokeObjectURL(url);
		throw new Error('Failed to render screenshot image');
	};
	img.src = url;
}

function downloadCanvas(canvas: HTMLCanvasElement, filename: string): void {
	const link = document.createElement('a');
	link.download = filename;
	link.href = canvas.toDataURL('image/png');
	document.body.appendChild(link);
	link.click();
	document.body.removeChild(link);
}
