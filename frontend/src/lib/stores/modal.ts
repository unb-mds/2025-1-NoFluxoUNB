import { writable } from 'svelte/store';

export type ModalType = 'confirm' | 'alert' | 'custom';

interface ModalConfig {
	type: ModalType;
	title: string;
	description?: string;
	confirmText?: string;
	cancelText?: string;
	component?: unknown;
	props?: Record<string, unknown>;
	onConfirm?: () => void | Promise<void>;
	onCancel?: () => void;
}

interface ModalState {
	isOpen: boolean;
	config: ModalConfig | null;
}

function createModalStore() {
	const { subscribe, set } = writable<ModalState>({
		isOpen: false,
		config: null
	});

	return {
		subscribe,
		open: (config: ModalConfig) => {
			set({ isOpen: true, config });
		},
		close: () => {
			set({ isOpen: false, config: null });
		},
		confirm: (options: Omit<ModalConfig, 'type'>) => {
			return new Promise<boolean>((resolve) => {
				set({
					isOpen: true,
					config: {
						type: 'confirm',
						...options,
						onConfirm: () => {
							options.onConfirm?.();
							resolve(true);
						},
						onCancel: () => {
							options.onCancel?.();
							resolve(false);
						}
					}
				});
			});
		},
		alert: (title: string, description?: string) => {
			return new Promise<void>((resolve) => {
				set({
					isOpen: true,
					config: {
						type: 'alert',
						title,
						description,
						confirmText: 'OK',
						onConfirm: () => resolve()
					}
				});
			});
		}
	};
}

export const modal = createModalStore();
