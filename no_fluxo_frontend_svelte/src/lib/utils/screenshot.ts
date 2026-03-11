/**
 * Screenshot utility — captura um elemento DOM como PNG e faz o download.
 * Usa html2canvas-pro (suporta oklab/oklch do Tailwind v4), com fallback nativo.
 */

const PADDING = 32;
const BG_COLOR = '#0a0a0f';
const BORDER_RADIUS = 12;

export async function captureScreenshot(
	element: HTMLElement,
	filename = 'fluxograma.png'
): Promise<void> {
	try {
		let html2canvas: ((el: HTMLElement, opts: Record<string, unknown>) => Promise<HTMLCanvasElement>) | null = null;
		try {
			const mod = await import('html2canvas-pro');
			html2canvas = mod.default ?? mod;
		} catch {
			// html2canvas não instalado — usa fallback
		}

		let canvas: HTMLCanvasElement;

		if (html2canvas) {
			canvas = await html2canvas(element, {
				backgroundColor: BG_COLOR,
				scale: 2,
				useCORS: true,
				logging: false,
				allowTaint: false,
				onclone: (_doc, clonedEl) => {
					clonedEl.style.overflow = 'visible';
					clonedEl.style.background = BG_COLOR;
				}
			});
			canvas = addPaddingAndRoundedCorners(canvas);
		} else {
			canvas = await captureWithSvgFallback(element);
		}

		downloadCanvas(canvas, filename);
	} catch (error) {
		console.error('Screenshot failed:', error);
		throw new Error('Não foi possível capturar a imagem do fluxograma.');
	}
}

async function captureWithSvgFallback(element: HTMLElement): Promise<HTMLCanvasElement> {
	const rect = element.getBoundingClientRect();
	const width = Math.round(rect.width);
	const height = Math.round(rect.height);

	const clone = element.cloneNode(true) as HTMLElement;
	const styles = getComputedStyle(element);
	clone.style.width = `${width}px`;
	clone.style.height = `${height}px`;
	clone.style.overflow = 'visible';
	clone.style.background = styles.background || BG_COLOR;

	const svgData = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><foreignObject width="100%" height="100%"><div xmlns="http://www.w3.org/1999/xhtml">${clone.outerHTML}</div></foreignObject></svg>`;
	const svgBlob = new Blob([svgData], { type: 'image/svg+xml;charset=utf-8' });
	const url = URL.createObjectURL(svgBlob);

	return new Promise((resolve, reject) => {
		const img = new Image();
		img.onload = () => {
			const canvas = document.createElement('canvas');
			canvas.width = (width + PADDING * 2) * 2;
			canvas.height = (height + PADDING * 2) * 2;
			const ctx = canvas.getContext('2d')!;
			ctx.fillStyle = BG_COLOR;
			ctx.fillRect(0, 0, canvas.width, canvas.height);
			ctx.scale(2, 2);
			ctx.drawImage(img, PADDING, PADDING);
			URL.revokeObjectURL(url);
			resolve(canvas);
		};
		img.onerror = () => {
			URL.revokeObjectURL(url);
			reject(new Error('Falha ao renderizar screenshot'));
		};
		img.src = url;
	});
}

function addPaddingAndRoundedCorners(source: HTMLCanvasElement): HTMLCanvasElement {
	const pad = PADDING * 2;
	const w = source.width + pad;
	const h = source.height + pad;

	const canvas = document.createElement('canvas');
	canvas.width = w;
	canvas.height = h;
	const ctx = canvas.getContext('2d')!;

	ctx.fillStyle = BG_COLOR;
	if (typeof ctx.roundRect === 'function') {
		ctx.beginPath();
		ctx.roundRect(0, 0, w, h, BORDER_RADIUS * 2);
		ctx.fill();
	} else {
		ctx.fillRect(0, 0, w, h);
	}
	ctx.drawImage(source, PADDING, PADDING);

	return canvas;
}

function downloadCanvas(canvas: HTMLCanvasElement, filename: string): void {
	const link = document.createElement('a');
	link.download = filename;
	link.href = canvas.toDataURL('image/png');
	document.body.appendChild(link);
	link.click();
	document.body.removeChild(link);
}
