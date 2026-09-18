/**
 * Chat store for managing AI assistant conversation state
 */

import { writable, derived, get } from 'svelte/store';

export interface ChatMessage {
	id: string;
	text: string;
	isUser: boolean;
	timestamp: Date;
	status: 'sending' | 'sent' | 'error';
}

interface ChatState {
	messages: ChatMessage[];
	isLoading: boolean;
	error: string | null;
	showQuickTags: boolean;
}

function generateId(): string {
	return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

const initialMessages: ChatMessage[] = [
	{
		id: generateId(),
		text: 'Olá! Sou o assistente NoFluxo. Estou aqui para te ajudar a encontrar matérias interessantes para adicionar ao seu fluxograma.\nMe conte quais áreas você tem interesse ou quais habilidades gostaria de desenvolver! Tente ser o mais curto possível na sua mensagem, para que eu consiga entender melhor o que você quer.',
		isUser: false,
		timestamp: new Date(),
		status: 'sent'
	}
];

const initialState: ChatState = {
	messages: initialMessages,
	isLoading: false,
	error: null,
	showQuickTags: true
};

function createChatStore() {
	const { subscribe, set, update } = writable<ChatState>(initialState);

	return {
		subscribe,

		addUserMessage(text: string): string {
			const id = generateId();
			const message: ChatMessage = {
				id,
				text,
				isUser: true,
				timestamp: new Date(),
				status: 'sending'
			};

			update((state) => ({
				...state,
				messages: [...state.messages, message],
				isLoading: true,
				showQuickTags: false,
				error: null
			}));

			return id;
		},

		updateMessageStatus(id: string, status: ChatMessage['status']) {
			update((state) => ({
				...state,
				messages: state.messages.map((msg) =>
					msg.id === id ? { ...msg, status } : msg
				)
			}));
		},

		addAIMessage(text: string) {
			const message: ChatMessage = {
				id: generateId(),
				text,
				isUser: false,
				timestamp: new Date(),
				status: 'sent'
			};

			update((state) => ({
				...state,
				messages: [...state.messages, message],
				isLoading: false
			}));
		},

		setLoading(isLoading: boolean) {
			update((state) => ({ ...state, isLoading }));
		},

		setError(error: string | null) {
			update((state) => ({ ...state, error, isLoading: false }));
		},

		retryMessage(id: string): string | null {
			const state = get({ subscribe });
			const message = state.messages.find((m) => m.id === id);
			if (message && message.status === 'error') {
				update((s) => ({
					...s,
					isLoading: true,
					error: null,
					messages: s.messages.map((msg) =>
						msg.id === id ? { ...msg, status: 'sending' as const } : msg
					)
				}));
				return message.text;
			}
			return null;
		},

		reset() {
			set(initialState);
		}
	};
}

export const chatStore = createChatStore();

// Derived stores for components
export const messages = derived(chatStore, ($state) => $state.messages);
export const isChatLoading = derived(chatStore, ($state) => $state.isLoading);
export const showQuickTags = derived(chatStore, ($state) => $state.showQuickTags);
export const chatError = derived(chatStore, ($state) => $state.error);
