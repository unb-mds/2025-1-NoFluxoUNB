/**
 * Copia o worker do pdfjs-dist para static/ para evitar 404 em produção.
 * Executado no postinstall.
 */
const fs = require('fs');
const path = require('path');

const pkgPath = require.resolve('pdfjs-dist/package.json');
const pdfjsDir = path.dirname(pkgPath);
const workerSrc = path.join(pdfjsDir, 'build', 'pdf.worker.min.mjs');
const staticDir = path.join(process.cwd(), 'static');
const dest = path.join(staticDir, 'pdf.worker.min.mjs');

if (!fs.existsSync(workerSrc)) {
	console.warn('[postinstall] pdf.worker.min.mjs não encontrado em', workerSrc);
	process.exit(0);
}

if (!fs.existsSync(staticDir)) {
	fs.mkdirSync(staticDir, { recursive: true });
}

fs.copyFileSync(workerSrc, dest);
console.log('[postinstall] pdf.worker.min.mjs copiado para static/');
