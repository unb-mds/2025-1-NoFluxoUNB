/**
 * extract_text.mjs
 * 
 * Extracts raw text from all histórico PDFs in this folder using pdfjs-dist
 * (same library as the Svelte frontend). Saves extracted text to .txt files
 * for inspection and pattern analysis.
 * 
 * This mirrors the logic in:
 *   no_fluxo_frontend_svelte/src/lib/services/pdf/pdfExtractor.ts
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// PDF.js setup for Node.js
const pdfjsLib = await import('pdfjs-dist/legacy/build/pdf.mjs');

// ─── Constants matching the Svelte frontend ───
const Y_PROXIMITY_THRESHOLD = 3;
const SPACE_GAP_THRESHOLD = 10;
const CHAR_WIDTH_ESTIMATE = 6;
const MAX_SPACES = 10;

// ─── Text extraction functions (ported from pdfExtractor.ts) ───

function groupItemsIntoLines(items) {
  const lines = new Map();

  for (const item of items) {
    let assignedY = null;
    for (const existingY of lines.keys()) {
      if (Math.abs(item.y - existingY) <= Y_PROXIMITY_THRESHOLD) {
        assignedY = existingY;
        break;
      }
    }
    if (assignedY !== null) {
      lines.get(assignedY).push(item);
    } else {
      lines.set(item.y, [item]);
    }
  }

  return lines;
}

function reconstructLine(items) {
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
    const textWidth = item.width > 0 ? item.width : item.text.length * CHAR_WIDTH_ESTIMATE;
    lastX = item.x + textWidth;
  }

  return result;
}

async function extractTextFromPdf(filePath) {
  const data = new Uint8Array(fs.readFileSync(filePath));
  const pdf = await pdfjsLib.getDocument({ data }).promise;

  const allLines = [];

  for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
    const page = await pdf.getPage(pageNum);
    const textContent = await page.getTextContent();

    const items = [];
    for (const item of textContent.items) {
      if (!('str' in item)) continue;
      const text = item.str.trim();
      if (!text) continue;
      items.push({
        text,
        x: item.transform[4],
        y: item.transform[5],
        width: item.width,
      });
    }

    const lineGroups = groupItemsIntoLines(items);
    for (const [y, lineItems] of lineGroups.entries()) {
      const lineText = reconstructLine(lineItems);
      if (lineText.trim()) {
        allLines.push([y, lineText, pageNum]);
      }
    }
  }

  // Sort lines: page ascending, then Y descending (top-to-bottom in PDF coordinates)
  allLines.sort((a, b) => {
    if (a[2] !== b[2]) return a[2] - b[2]; // page
    return b[0] - a[0]; // Y descending
  });

  return {
    text: allLines.map(([, text]) => text).join('\n'),
    lines: allLines.map(([y, text, page]) => ({ y, text, page })),
    pageCount: pdf.numPages,
  };
}

// ─── Main ───

const outputDir = path.join(__dirname, 'extracted_texts');
fs.mkdirSync(outputDir, { recursive: true });

const pdfFiles = fs.readdirSync(__dirname).filter(f => f.endsWith('.pdf'));
console.log(`\n${'='.repeat(70)}`);
console.log(`  PDF TEXT EXTRACTION — ${pdfFiles.length} files found`);
console.log(`${'='.repeat(70)}\n`);

const results = [];

for (const pdfFile of pdfFiles) {
  const filePath = path.join(__dirname, pdfFile);
  console.log(`\n--- Processing: ${pdfFile} ---`);

  try {
    const result = await extractTextFromPdf(filePath);
    console.log(`  Pages: ${result.pageCount}`);
    console.log(`  Lines: ${result.lines.length}`);
    console.log(`  Chars: ${result.text.length}`);

    // Save full text
    const baseName = path.basename(pdfFile, '.pdf');
    const txtPath = path.join(outputDir, `${baseName}.txt`);
    fs.writeFileSync(txtPath, result.text);
    console.log(`  Saved: ${txtPath}`);

    // Save with line numbers for analysis
    const numberedPath = path.join(outputDir, `${baseName}_numbered.txt`);
    const numbered = result.lines
      .map((l, idx) => `L${String(idx).padStart(3, '0')} [P${l.page} Y${l.y.toFixed(0).padStart(4)}]: ${l.text}`)
      .join('\n');
    fs.writeFileSync(numberedPath, numbered);
    console.log(`  Saved numbered: ${numberedPath}`);

    results.push({ file: pdfFile, ...result });

  } catch (err) {
    console.error(`  ERROR: ${err.message}`);
  }
}

// Save summary
const summaryPath = path.join(outputDir, '_summary.json');
const summary = results.map(r => ({
  file: r.file,
  pages: r.pageCount,
  lines: r.lines.length,
  chars: r.text.length,
  first10Lines: r.text.split('\n').slice(0, 10),
}));
fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));

console.log(`\n${'='.repeat(70)}`);
console.log(`  DONE — ${results.length} files extracted`);
console.log(`  Output directory: ${outputDir}`);
console.log(`${'='.repeat(70)}\n`);
