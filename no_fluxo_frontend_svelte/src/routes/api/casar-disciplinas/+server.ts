// Discipline matching logic moved to Supabase Edge Function.
// See: supabase/functions/casar-disciplinas/index.ts
//
// The frontend now calls the Edge Function via:
//   supabase.functions.invoke('casar-disciplinas', { body: { dados_extraidos } })
//
// This file is kept empty to avoid breaking the route structure during transition.
// It can be safely deleted once the Edge Function is deployed.
