import { createClient } from '@supabase/supabase-js'

// Set these in a .env file at project root (see README):
// VITE_SUPABASE_URL=...
// VITE_SUPABASE_ANON_KEY=...
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
)

export async function fetchEntries() {
  const { data, error } = await supabase
    .from('entries')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return data
}

export async function addEntry(amount, note) {
  const { data, error } = await supabase
    .from('entries')
    .insert({ amount, note })
    .select()
    .single()
  if (error) throw error
  return data
}

export async function deleteEntry(id) {
  const { error } = await supabase.from('entries').delete().eq('id', id)
  if (error) throw error
}
