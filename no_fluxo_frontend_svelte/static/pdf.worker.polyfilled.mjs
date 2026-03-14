// Polyfill Uint8Array.prototype.toHex for browsers that lack it (e.g. older Chrome/Edge).
// pdf.js 5.x uses this method internally in the worker and will throw if it's missing.
if (typeof Uint8Array.prototype.toHex !== 'function') {
	Uint8Array.prototype.toHex = function () {
		return Array.from(this, (b) => b.toString(16).padStart(2, '0')).join('');
	};
}

// Polyfill Uint8Array.fromHex (also used by pdf.js 5.x)
if (typeof Uint8Array.fromHex !== 'function') {
	Uint8Array.fromHex = function (hexString) {
		const bytes = new Uint8Array(hexString.length / 2);
		for (let i = 0; i < hexString.length; i += 2) {
			bytes[i / 2] = parseInt(hexString.substring(i, i + 2), 16);
		}
		return bytes;
	};
}

import './pdf.worker.min.mjs';
