import type { UserModel } from './user';

// Re-export UserModel for backward compatibility
export type { UserModel };

export interface AuthState {
	user: UserModel | null;
	isAuthenticated: boolean;
	isAnonymous: boolean;
	isLoading: boolean;
	error: string | null;
}
