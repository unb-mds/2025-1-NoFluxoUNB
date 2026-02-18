import type { Session, SupabaseClient, User } from '@supabase/supabase-js';

declare global {
	namespace App {
		interface Locals {
			supabase: SupabaseClient;
			getSession: () => Promise<Session | null>;
			getUser: () => Promise<User | null>;
		}
		interface PageData {
			session: Session | null;
		}
	}
}

export { };
