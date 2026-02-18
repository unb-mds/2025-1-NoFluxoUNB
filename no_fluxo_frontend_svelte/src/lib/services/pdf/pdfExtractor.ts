import type { TextItem } from 'pdfjs-dist/types/src/display/api';

const LOG_PREFIX = '[PDF-Extractor]';

let pdfjsLoaded = false;

/**
 * Dynamically imports pdfjs-dist so it is never evaluated during SSR
 * (the library references DOMMatrix at module scope, which doesn't exist in Node).
 */
async function getPdfjs() {
	const pdfjs = await import('pdfjs-dist');
	if (!pdfjsLoaded) {
		pdfjs.GlobalWorkerOptions.workerSrc = new URL(
			'pdfjs-dist/build/pdf.worker.min.mjs',
			import.meta.url
		).toString();
		pdfjsLoaded = true;
	}
	return pdfjs;
}

/** Threshold in points for grouping text items into the same line by Y proximity. */
const Y_PROXIMITY_THRESHOLD = 3;

/** Distance in points beyond which a space is inserted between items. */
const SPACE_GAP_THRESHOLD = 10;

/** Estimated width per character in points (for fallback width calculation). */
const CHAR_WIDTH_ESTIMATE = 6;

/** Maximum number of spaces inserted for a single gap. */
const MAX_SPACES = 10;

export interface PositionedTextItem {
	text: string;
	x: number;
	y: number;
	width: number;
}

/**
 * Groups text items into lines based on Y-position proximity.
 * Items within `Y_PROXIMITY_THRESHOLD` points of each other are considered
 * to be on the same line.
 */
function groupItemsIntoLines(items: PositionedTextItem[]): Map<number, PositionedTextItem[]> {
	const lines = new Map<number, PositionedTextItem[]>();

	for (const item of items) {
		let assignedY: number | null = null;

		for (const existingY of lines.keys()) {
			if (Math.abs(item.y - existingY) <= Y_PROXIMITY_THRESHOLD) {
				assignedY = existingY;
				break;
			}
		}

		if (assignedY !== null) {
			lines.get(assignedY)!.push(item);
		} else {
			lines.set(item.y, [item]);
		}
	}

	return lines;
}

/**
 * Reconstructs a single line of text from a set of items sorted by X position.
 * Inserts spaces between items when the horizontal gap exceeds
 * `SPACE_GAP_THRESHOLD` points, matching the Python backend logic:
 *   spaces = max(1, int((x - lastX) / 6)), capped at 10.
 */
function reconstructLine(items: PositionedTextItem[]): string {
	// Sort items left-to-right by X position
	items.sort((a, b) => a.x - b.x);

	let result = '';
	let lastX = -Infinity;

	for (const item of items) {
		if (lastX > -Infinity && item.x > lastX + SPACE_GAP_THRESHOLD) {
			const gap = item.x - lastX;
			const spaceCount = Math.min(Math.max(1, Math.floor(gap / CHAR_WIDTH_ESTIMATE)), MAX_SPACES);
			result += ' '.repeat(spaceCount);
		}

		result += item.text;

		// Estimate end position: use actual width if available, otherwise estimate
		const textWidth = item.width > 0 ? item.width : item.text.length * CHAR_WIDTH_ESTIMATE;
		lastX = item.x + textWidth;
	}

	return result;
}

/**
 * Extracts structured text from a PDF file, reconstructing lines by sorting
 * text items by vertical then horizontal position.
 *
 * Ports the `extract_structured_text()` logic from the Python backend
 * (pdf_parser_final.py) to run client-side using PDF.js.
 *
 * @param file - The PDF File object to extract text from.
 * @returns The full reconstructed text with lines separated by newlines.
 */
export async function extractTextFromPdf(file: File): Promise<string> {
	console.log(`${LOG_PREFIX} Starting text extraction from "${file.name}" (${(file.size / 1024).toFixed(1)} KB)`);
	const startTime = performance.now();

	const pdfjs = await getPdfjs();
	const arrayBuffer = await file.arrayBuffer();
	const pdf = await pdfjs.getDocument({ data: arrayBuffer }).promise;
	console.log(`${LOG_PREFIX} PDF loaded — ${pdf.numPages} page(s)`);

	const allLines: [number, string][] = [];

	for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
		const page = await pdf.getPage(pageNum);
		const textContent = await page.getTextContent();
		console.log(`${LOG_PREFIX} Page ${pageNum}: ${textContent.items.length} raw text items`);

		const items: PositionedTextItem[] = [];

		for (const item of textContent.items) {
			// Filter out non-text items (e.g. marked content)
			if (!('str' in item)) continue;

			const textItem = item as TextItem;
			const text = textItem.str.trim();
			if (!text) continue;

			items.push({
				text,
				x: textItem.transform[4],
				y: textItem.transform[5],
				width: textItem.width
			});
		}

		// Group items into lines by Y proximity
		const lineGroups = groupItemsIntoLines(items);

		// Reconstruct each line and store with Y position
		for (const [y, lineItems] of lineGroups.entries()) {
			const lineText = reconstructLine(lineItems);
			if (lineText.trim()) {
				allLines.push([y, lineText]);
			}
		}
	}

	// Sort lines by Y descending (PDF.js Y increases upward, so descending = top to bottom)
	allLines.sort((a, b) => b[0] - a[0]);

	const result = allLines.map(([, text]) => text).join('\n');
	const elapsed = (performance.now() - startTime).toFixed(0);
	console.log(`${LOG_PREFIX} Text extraction complete — ${allLines.length} lines, ${result.length} chars in ${elapsed}ms`);
	return result;
}

/**
 * Extracts positioned text items from a PDF file, one array per page.
 * Each item retains its x, y coordinates and width from PDF.js.
 * This is used by the position-based discipline extractor.
 */
export async function extractPositionedItems(file: File): Promise<PositionedTextItem[][]> {
	const pdfjs = await getPdfjs();
	const arrayBuffer = await file.arrayBuffer();
	const pdf = await pdfjs.getDocument({ data: arrayBuffer }).promise;

	const pages: PositionedTextItem[][] = [];

	for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
		const page = await pdf.getPage(pageNum);
		const textContent = await page.getTextContent();

		const items: PositionedTextItem[] = [];
		for (const item of textContent.items) {
			if (!('str' in item)) continue;
			const textItem = item as TextItem;
			const text = textItem.str.trim();
			if (!text) continue;
			items.push({
				text,
				x: textItem.transform[4],
				y: textItem.transform[5],
				width: textItem.width
			});
		}

		pages.push(items);
	}

	return pages;
}

/**
 * Extracts a matrícula (student ID) from a PDF filename.
 *
 * Expects filenames in the format `prefix_MATRICULA.pdf`.
 * Returns `'desconhecida'` if the pattern doesn't match.
 */
export function extractMatriculaFromFilename(filename: string): string {
	if (filename.includes('_')) {
		try {
			return filename.split('_')[1].split('.')[0];
		} catch {
			return 'desconhecida';
		}
	}
	return 'desconhecida';
}
