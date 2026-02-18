import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';
import type { Snippet } from 'svelte';
import type { HTMLAttributes } from 'svelte/elements';

/**
 * Merge Tailwind CSS classes with proper precedence
 */
export function cn(...inputs: ClassValue[]) {
	return twMerge(clsx(inputs));
}

// shadcn-svelte type helpers

export type WithElementRef<T> = T & {
	ref?: HTMLElement | null;
};

export type WithoutChildren<T> = T extends { children?: unknown }
	? Omit<T, 'children'>
	: T;

export type WithoutChild<T> = T extends { child?: unknown }
	? Omit<T, 'child'>
	: T;

export type WithoutChildrenOrChild<T> = WithoutChildren<WithoutChild<T>>;

// Re-export everything from utils/index.ts
export { formatDate, formatPercentage, debounce, sleep, isBrowser } from './utils/index.js';
