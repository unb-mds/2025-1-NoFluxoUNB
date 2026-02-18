/**
 * Text utility functions for the AI assistant.
 */

/**
 * Remove accents/diacritics from a string.
 * Equivalent to the Python `remover_acentos_nativo()`.
 */
export function removeAccents(text: string): string {
    if (!text) return '';
    return text.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

/**
 * Unescape HTML entities in a string.
 */
export function unescapeHtml(text: string): string {
    const entities: Record<string, string> = {
        '&amp;': '&',
        '&lt;': '<',
        '&gt;': '>',
        '&quot;': '"',
        '&#39;': "'",
        '&#x27;': "'",
        '&apos;': "'",
        '&#x2F;': '/',
        '&nbsp;': ' ',
    };
    return text.replace(/&(?:#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (match) => {
        return entities[match] || match;
    });
}
