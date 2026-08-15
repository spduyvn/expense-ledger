import { createClient } from '@supabase/supabase-js'

// Set these in a .env file at project root (see README):
// VITE_SUPABASE_URL=...
// VITE_SUPABASE_ANON_KEY=...
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
)

export async function signInWithMagicLink(email) {
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: window.location.origin
    }
  })
  if (error) throw error
}

export async function signInAnonymously() {
  const { data, error } = await supabase.auth.signInAnonymously()
  if (error) throw error
  return data.session
}

export async function signOut() {
  const { error } = await supabase.auth.signOut()
  if (error) throw error
}

export async function getSession() {
  const { data, error } = await supabase.auth.getSession()
  if (error) throw error
  return data.session
}

export function onAuthStateChange(callback) {
  const { data } = supabase.auth.onAuthStateChange((_event, session) => {
    callback(session)
  })
  return data.subscription
}

export async function fetchEntries() {
  const { data, error } = await supabase
    .from('entries')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return data
}

export async function addEntry(amount, note, accountType, tag, entryType = 'transaction', countsTowardDaily = true) {
  const { data, error } = await supabase
    .from('entries')
    .insert({ amount, note, account_type: accountType, tag, entry_type: entryType, counts_toward_daily: countsTowardDaily })
    .select()
    .single()
  if (error) throw error
  return data
}

export async function deleteEntry(id) {
  const { error } = await supabase.from('entries').delete().eq('id', id)
  if (error) throw error
}

export async function fetchTags() {
  const { data, error } = await supabase
    .from('tags')
    .select('*')
    .order('name', { ascending: true })
  if (error) throw error
  return data
}

export async function addTags(names) {
  const { data, error } = await supabase
    .from('tags')
    .insert(names.map((name) => ({ name })))
    .select()
  if (error) throw error
  return data
}

export async function updateTag(id, name) {
  const { data, error } = await supabase
    .from('tags')
    .update({ name })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data
}

export async function deleteTag(id) {
  const { error } = await supabase.from('tags').delete().eq('id', id)
  if (error) throw error
}

export async function fetchDebtData() {
  const [accountsResult, entriesResult, plansResult] = await Promise.all([
    supabase.from('debt_accounts').select('*').order('created_at', { ascending: false }),
    supabase.from('debt_entries').select('*').order('occurred_at', { ascending: false }),
    supabase.from('debt_month_plans').select('*').order('month', { ascending: true })
  ])
  const error = accountsResult.error || entriesResult.error || plansResult.error
  if (error) throw error
  return { accounts: accountsResult.data, entries: entriesResult.data, plans: plansResult.data }
}

async function callDebtRpc(name, args) {
  const { error } = await supabase.rpc(name, args)
  if (error) throw error
}

export function createDebtAccount(name, note, openingAmount, plans) {
  return callDebtRpc('create_debt_account', {
    p_name: name,
    p_note: note,
    p_opening_amount: openingAmount,
    p_plans: plans
  })
}

export function addDebtIncrease(debtId, amount, note, plans) {
  return callDebtRpc('add_debt_increase', {
    p_debt_id: debtId,
    p_amount: amount,
    p_note: note,
    p_plans: plans
  })
}

export function payDebt(debtId, amount, accountType, note) {
  return callDebtRpc('pay_debt', {
    p_debt_id: debtId,
    p_amount: amount,
    p_account_type: accountType,
    p_note: note
  })
}

export function updateDebtAccount(debtId, name, note) {
  return callDebtRpc('update_debt_account', { p_debt_id: debtId, p_name: name, p_note: note })
}

export function deleteDebtAccount(debtId) {
  return callDebtRpc('delete_debt_account', { p_debt_id: debtId })
}

export function saveDebtPlan(debtId, month, amount) {
  return callDebtRpc('save_debt_plan', { p_debt_id: debtId, p_month: month, p_amount: amount })
}

export function deleteDebtPlan(debtId, month) {
  return callDebtRpc('delete_debt_plan', { p_debt_id: debtId, p_month: month })
}
