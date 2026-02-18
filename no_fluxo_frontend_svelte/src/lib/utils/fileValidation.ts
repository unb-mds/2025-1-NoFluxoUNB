/**
 * File validation utilities for PDF upload
 */

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
const ALLOWED_MIME_TYPES = ['application/pdf'];
const ALLOWED_EXTENSIONS = ['.pdf'];

export interface ValidationResult {
	valid: boolean;
	error?: string;
}

export function validatePdfFile(file: File): ValidationResult {
	if (!file) {
		return { valid: false, error: 'Nenhum arquivo selecionado.' };
	}

	// Check file extension
	const fileName = file.name.toLowerCase();
	const hasValidExtension = ALLOWED_EXTENSIONS.some((ext) => fileName.endsWith(ext));
	if (!hasValidExtension) {
		return { valid: false, error: 'Formato inválido. Somente arquivos PDF são aceitos.' };
	}

	// Check MIME type
	if (!ALLOWED_MIME_TYPES.includes(file.type)) {
		return { valid: false, error: 'Formato inválido. Somente arquivos PDF são aceitos.' };
	}

	// Check file size
	if (file.size > MAX_FILE_SIZE) {
		const sizeMB = (file.size / (1024 * 1024)).toFixed(1);
		return {
			valid: false,
			error: `Arquivo muito grande (${sizeMB}MB). O tamanho máximo é 10MB.`
		};
	}

	if (file.size === 0) {
		return { valid: false, error: 'O arquivo está vazio.' };
	}

	return { valid: true };
}

export function formatFileSize(bytes: number): string {
	if (bytes < 1024) return `${bytes} B`;
	if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
	return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
