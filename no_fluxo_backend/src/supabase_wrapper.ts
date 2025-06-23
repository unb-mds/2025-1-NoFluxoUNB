import { createClient, SupabaseClient } from '@supabase/supabase-js'

export const SupabaseWrapper = {
    _supabase: null as SupabaseClient | null,
    init: () => {
        const supabaseUrl = process.env.SUPABASE_URL;
        const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
        
        if (!supabaseUrl || !supabaseKey) {
            throw new Error('SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY devem estar definidos no arquivo .env');
        }
        
        SupabaseWrapper._supabase = createClient(supabaseUrl, supabaseKey);
    },
    get: () => {
        if (!SupabaseWrapper._supabase) {
            throw new Error('SupabaseWrapper not initialized')
        }
        return SupabaseWrapper._supabase
    },
}