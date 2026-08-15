<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import Login from './components/Login.vue'
import LedgerHeader from './components/LedgerHeader.vue'
import EntryForm from './components/EntryForm.vue'
import TodayPage from './components/TodayPage.vue'
import HistoryPage from './components/HistoryPage.vue'
import AppDialogs from './components/AppDialogs.vue'
import SettingsModal from './components/SettingsModal.vue'
import DebtManager from './components/DebtManager.vue'
import { fetchEntries, addEntry, deleteEntry, fetchTags, addTags, updateTag, deleteTag, fetchDebtData, createDebtAccount, addDebtIncrease, payDebt, signInAnonymously, signOut, getSession, onAuthStateChange } from './supabase'

const entries = ref([])
const tags = ref([])
const debtAccounts = ref([])
const debtEntries = ref([])
const debtPlans = ref([])
const session = ref(null)
const authLoading = ref(true)
const localAuthError = ref('')
const input = ref('')
const note = ref('')
const selectedAccountType = ref(null)
const selectedTag = ref(null)
const tagModalOpen = ref(false)
const tagInput = ref('')
const editingTagId = ref(null)
const editingTagName = ref('')
const entryDirection = ref(-1)
const countsTowardDaily = ref(true)
const balancesHidden = ref(false)
const dailyInfoOpen = ref(false)
const dailyInfoRef = ref(null)
const editingBalance = ref(false)
const balanceInput = ref('')
const savingBalance = ref(false)
const loading = ref(true)
const error = ref('')
const activeView = ref('today')
const historyPeriod = ref('month')
const searchQuery = ref('')
const dateSearchMode = ref('day')
const dateFrom = ref('')
const dateTo = ref('')
const currentPage = ref(1)
const todayPage = ref(1)
const detailRows = ref([])
const detailTitle = ref('')
const detailPage = ref(1)
const selectedEntryDetail = ref(null)
const confirmingEntry = ref(null)
const debtManagerOpen = ref(false)
const settingsOpen = ref(false)
const appearance = ref('ledger')
const pageSize = 10
const accountTypes = [
  { value: 'cash', label: 'Tiền mặt' },
  { value: 'bank', label: 'Tài khoản' },
  { value: 'wallet', label: 'Ví' }
]
const balanceAccountTypes = [
  { value: 'wallet', label: 'Ví' },
  { value: 'bank', label: 'Tài khoản' },
  { value: 'cash', label: 'Tiền mặt' }
]
const defaultTagNames = ['Ăn uống', 'Di chuyển', 'Mua sắm', 'Hoá đơn', 'Giải trí', 'Sức khoẻ', 'Khác']
const isLocalEnvironment = import.meta.env.VITE_APP_ENV === 'local'

let authSubscription
let dailyInfoTimer

onMounted(async () => {
  document.addEventListener('keydown', handleKeydown)
  document.addEventListener('pointerdown', handleOutsidePointerDown)
  try {
    balancesHidden.value = localStorage.getItem('dmoney-balances-hidden') === 'true'
    const savedAppearance = localStorage.getItem('dmoney-appearance')
    if (['ledger', 'modern', 'midnight', 'breeze'].includes(savedAppearance)) appearance.value = savedAppearance
  } catch (e) {
    // Giữ trạng thái mặc định nếu trình duyệt chặn localStorage.
  }
  try {
    session.value = isLocalEnvironment ? await getLocalSession() : await getSession()
    if (session.value) await load()
  } catch (e) {
    if (isLocalEnvironment) {
      localAuthError.value = 'Không thể tạo phiên test local. Hãy bật Anonymous Sign-Ins trong Supabase Authentication → Providers → Anonymous.'
    } else {
      error.value = 'Không kiểm tra được trạng thái đăng nhập. Vui lòng thử lại.'
    }
  } finally {
    authLoading.value = false
  }

  authSubscription = onAuthStateChange(async (nextSession) => {
    const didChangeUser = session.value?.user?.id !== nextSession?.user?.id
    session.value = nextSession

    if (nextSession && didChangeUser) {
      await load()
    } else if (!nextSession) {
      entries.value = []
      tags.value = []
      debtAccounts.value = []
      debtEntries.value = []
      debtPlans.value = []
      loading.value = false
      error.value = ''
    }
  })
})

onUnmounted(() => {
  authSubscription?.unsubscribe()
  clearTimeout(dailyInfoTimer)
  document.removeEventListener('keydown', handleKeydown)
  document.removeEventListener('pointerdown', handleOutsidePointerDown)
})

async function getLocalSession() {
  const currentSession = await getSession()
  if (currentSession?.user?.is_anonymous) return currentSession
  if (currentSession) await signOut()
  return signInAnonymously()
}

async function load() {
  loading.value = true
  try {
    const [loadedEntries, loadedTags, loadedDebtData] = await Promise.all([fetchEntries(), fetchTags(), fetchDebtData()])
    entries.value = loadedEntries
    tags.value = loadedTags
    debtAccounts.value = loadedDebtData.accounts
    debtEntries.value = loadedDebtData.entries
    debtPlans.value = loadedDebtData.plans
    await seedDefaultTags()
  } catch (e) {
    error.value = 'Không tải được sổ. Kiểm tra kết nối Supabase.'
  } finally {
    loading.value = false
  }
}

async function seedDefaultTags() {
  if (tags.value.length) return
  const createdTags = await addTags(defaultTagNames)
  tags.value = [...tags.value, ...createdTags].sort((a, b) => a.name.localeCompare(b.name, 'vi'))
}

async function handleSignOut() {
  try {
    settingsOpen.value = false
    await signOut()
  } catch (e) {
    error.value = 'Không thể đăng xuất. Vui lòng thử lại.'
  }
}

// Số dư được tính luỹ kế trên toàn bộ sổ, từ giao dịch cũ nhất đến mới nhất.
const withBalance = computed(() => {
  const chrono = [...entries.value].sort((a, b) => {
    const timeDiff = new Date(a.created_at) - new Date(b.created_at)
    return timeDiff || a.id.localeCompare(b.id)
  })
  let running = 0
  const runningByAccount = { cash: 0, bank: 0, wallet: 0 }
  const rows = chrono.map((e) => {
    const amount = Number(e.amount)
    const accountType = e.account_type || 'cash'
    const isAdjustment = e.entry_type === 'adjustment'
    if (!isAdjustment) {
      running += amount
      runningByAccount[accountType] += amount
    }
    return {
      ...e,
      account_type: accountType,
      balance: running,
      accountBalance: runningByAccount[accountType]
    }
  })
  return rows.reverse()
})

const currentBalance = computed(() => entries.value.reduce((total, entry) => total + Number(entry.amount), 0))
const balancesByAccount = computed(() => entries.value.reduce((balances, entry) => {
  const accountType = entry.account_type || 'cash'
  balances[accountType] += Number(entry.amount)
  return balances
}, { cash: 0, bank: 0, wallet: 0 }))
const currentDate = new Intl.DateTimeFormat('vi-VN', {
  weekday: 'long',
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
  timeZone: 'UTC'
}).format(new Date())

function utcDateKey(value) {
  const date = new Date(value)
  const year = date.getUTCFullYear()
  const month = String(date.getUTCMonth() + 1).padStart(2, '0')
  const day = String(date.getUTCDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function isSameUtcDay(value, date) {
  return utcDateKey(value) === utcDateKey(date)
}

function startOfUtcDay(date = new Date()) {
  const result = new Date(date)
  result.setUTCHours(0, 0, 0, 0)
  return result
}

function isInHistoryPeriod(value) {
  const date = new Date(value)
  const now = new Date()
  const today = startOfUtcDay(now)

  if (historyPeriod.value === 'day') return true

  if (historyPeriod.value === 'week') {
    const weekStart = new Date(today)
    const weekday = weekStart.getUTCDay() || 7
    weekStart.setUTCDate(weekStart.getUTCDate() - weekday + 1)
    return date >= weekStart && date <= now
  }

  return date.getUTCFullYear() === now.getUTCFullYear() && date.getUTCMonth() === now.getUTCMonth()
}

function isInCurrentMonth(value) {
  const date = new Date(value)
  const now = new Date()
  return date.getUTCFullYear() === now.getUTCFullYear() && date.getUTCMonth() === now.getUTCMonth()
}

function fmtTime(value) {
  return new Intl.DateTimeFormat('vi-VN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone: 'Asia/Ho_Chi_Minh'
  }).format(new Date(value))
}

function groupByDay(rows) {
  const groups = []
  let currentDay = null
  for (const row of rows) {
    const day = new Date(row.created_at).toLocaleDateString('vi-VN', {
      weekday: 'short', day: '2-digit', month: '2-digit', timeZone: 'UTC'
    })
    if (day !== currentDay) {
      groups.push({ day, rows: [] })
      currentDay = day
    }
    groups[groups.length - 1].rows.push(row)
  }
  return groups
}
function normalizeSearch(value) {
  return String(value ?? '').toLocaleLowerCase('vi-VN').trim()
}

const filteredRows = computed(() => {
  const query = normalizeSearch(searchQuery.value)
  if (!query) return withBalance.value

  const compactQuery = query.replace(/[.,\s]/g, '')
  return withBalance.value.filter((row) => {
    const noteMatches = normalizeSearch(row.note).includes(query)
    const tagMatches = normalizeSearch(row.tag).includes(query)
    const accountMatches = normalizeSearch(accountLabel(row.account_type)).includes(query)
    const amount = Number(row.amount)
    const amountValues = [
      String(row.amount),
      String(amount),
      String(Math.abs(amount)),
      fmt(amount),
      fmt(Math.abs(amount))
    ]
    const amountMatches = amountValues.some((value) => {
      const normalizedValue = normalizeSearch(value)
      return normalizedValue.includes(query)
        || normalizedValue.replace(/[.,\s]/g, '').includes(compactQuery)
    })
    return noteMatches || tagMatches || accountMatches || amountMatches
  })
})

function matchesDateSearch(row) {
  const day = utcDateKey(row.created_at)
  if (dateSearchMode.value === 'day') return !dateFrom.value || day === dateFrom.value
  if (dateFrom.value && day < dateFrom.value) return false
  if (dateTo.value && day > dateTo.value) return false
  return true
}

const todayRows = computed(() => withBalance.value.filter((row) => isSameUtcDay(row.created_at, new Date())))
const dailyBalance = computed(() => todayRows.value
  .filter(isCountedTowardDaily)
  .reduce((total, row) => total + Number(row.amount), 0))
const dailyIncome = computed(() => todayRows.value
  .filter((row) => isCountedTowardDaily(row) && Number(row.amount) > 0)
  .reduce((total, row) => total + Number(row.amount), 0))
const dailyExpense = computed(() => todayRows.value
  .filter((row) => isCountedTowardDaily(row) && Number(row.amount) < 0)
  .reduce((total, row) => total + Math.abs(Number(row.amount)), 0))
const currentDebtMonth = computed(() => `${new Date().getUTCFullYear()}-${String(new Date().getUTCMonth() + 1).padStart(2, '0')}-01`)
const debts = computed(() => debtAccounts.value.map((account) => {
  const entries = debtEntries.value.filter((entry) => entry.debt_id === account.id)
  const plans = debtPlans.value.filter((plan) => plan.debt_id === account.id)
  const balance = entries.reduce((total, entry) => total + Number(entry.amount), 0)
  const monthPlanned = plans.filter((plan) => plan.month === currentDebtMonth.value).reduce((total, plan) => total + Number(plan.planned_amount), 0)
  const monthPaid = entries.filter((entry) => entry.entry_type === 'payment' && String(entry.occurred_at).slice(0, 7) === currentDebtMonth.value.slice(0, 7)).reduce((total, entry) => total + Math.abs(Number(entry.amount)), 0)
  return { ...account, entries, plans: plans.map((plan) => ({ month: plan.month, amount: Number(plan.planned_amount) })), balance, monthPlanned, monthPaid, monthRemaining: Math.max(0, monthPlanned - monthPaid) }
}).filter((debt) => debt.balance > 0))
const currentDebt = computed(() => debts.value.reduce((total, debt) => total + debt.balance, 0))
const currentMonthDebt = computed(() => debts.value.reduce((total, debt) => total + debt.monthRemaining, 0))
const todayTotalPages = computed(() => Math.max(1, Math.ceil(todayRows.value.length / pageSize)))
const paginatedTodayRows = computed(() => {
  const start = (todayPage.value - 1) * pageSize
  return todayRows.value.slice(start, start + pageSize)
})
const todayVisibleRange = computed(() => {
  if (!todayRows.value.length) return ''
  const start = (todayPage.value - 1) * pageSize + 1
  const end = Math.min(start + pageSize - 1, todayRows.value.length)
  return `${start}–${end} trên ${todayRows.value.length} giao dịch`
})
const hasDateSearch = computed(() => Boolean(dateFrom.value || dateTo.value))
const historyRows = computed(() => filteredRows.value.filter((row) => (
  matchesDateSearch(row) && (hasDateSearch.value ? true : isInHistoryPeriod(row.created_at))
)))

const dailySummaries = computed(() => {
  const summaryByDay = new Map()
  for (const row of historyRows.value) {
    const key = utcDateKey(row.created_at)
    if (!summaryByDay.has(key)) {
      summaryByDay.set(key, { key, rows: [], income: 0, expense: 0 })
    }
    const summary = summaryByDay.get(key)
    summary.rows.push(row)
    if (isCountedTowardDaily(row)) {
      if (Number(row.amount) >= 0) summary.income += Number(row.amount)
      else summary.expense += Math.abs(Number(row.amount))
    }
  }
  return [...summaryByDay.values()].map((summary) => ({
    ...summary,
    net: summary.income - summary.expense,
    label: formatDayLabel(summary.key)
  }))
})

const chartBuckets = computed(() => {
  const now = new Date()
  const start = startOfUtcDay(now)
  const buckets = []
  let count = historyPeriod.value === 'week' ? 7 : new Date(now.getUTCFullYear(), now.getUTCMonth() + 1, 0).getUTCDate()
  if (hasDateSearch.value) {
    const firstKey = dateFrom.value || utcDateKey(historyRows.value.at(-1)?.created_at || now)
    const lastKey = dateTo.value || utcDateKey(historyRows.value[0]?.created_at || now)
    const [startYear, startMonth, startDay] = firstKey.split('-').map(Number)
    const [endYear, endMonth, endDay] = lastKey.split('-').map(Number)
    start.setTime(Date.UTC(startYear, startMonth - 1, startDay))
    const end = new Date(Date.UTC(endYear, endMonth - 1, endDay))
    count = Math.max(1, Math.round((end - start) / 86400000) + 1)
  } else if (historyPeriod.value === 'week') {
    const weekday = start.getUTCDay() || 7
    start.setUTCDate(start.getUTCDate() - weekday + 1)
  } else {
    start.setUTCDate(1)
  }
  for (let index = 0; index < count; index += 1) {
    const date = new Date(start)
    date.setUTCDate(start.getUTCDate() + index)
    const key = utcDateKey(date)
    const rows = historyRows.value.filter((row) => utcDateKey(row.created_at) === key)
    const income = rows.filter((row) => isCountedTowardDaily(row) && Number(row.amount) > 0).reduce((sum, row) => sum + Number(row.amount), 0)
    const expense = rows.filter((row) => isCountedTowardDaily(row) && Number(row.amount) < 0).reduce((sum, row) => sum + Math.abs(Number(row.amount)), 0)
    buckets.push({ key, rows, income, expense, label: historyPeriod.value === 'week' ? formatWeekday(key) : String(index + 1) })
  }
  return buckets
})
const chartMax = computed(() => Math.max(1, ...chartBuckets.value.flatMap((bucket) => [bucket.income, bucket.expense])))
const chartIncomeTotal = computed(() => chartBuckets.value.reduce((sum, bucket) => sum + bucket.income, 0))
const chartExpenseTotal = computed(() => chartBuckets.value.reduce((sum, bucket) => sum + bucket.expense, 0))

const totalPages = computed(() => Math.max(1, Math.ceil(historyRows.value.length / pageSize)))
const paginatedRows = computed(() => {
  const start = (currentPage.value - 1) * pageSize
  return historyRows.value.slice(start, start + pageSize)
})
const grouped = computed(() => groupByDay(paginatedRows.value))
const visibleRange = computed(() => {
  if (!historyRows.value.length) return ''
  const start = (currentPage.value - 1) * pageSize + 1
  const end = Math.min(start + pageSize - 1, historyRows.value.length)
  return `${start}–${end} trên ${historyRows.value.length} giao dịch`
})
const dailySummaryPages = computed(() => Math.max(1, Math.ceil(dailySummaries.value.length / pageSize)))
const paginatedDailySummaries = computed(() => dailySummaries.value.slice((currentPage.value - 1) * pageSize, currentPage.value * pageSize))
const dailySummaryRange = computed(() => {
  if (!dailySummaries.value.length) return ''
  const start = (currentPage.value - 1) * pageSize + 1
  return `${start}–${Math.min(start + pageSize - 1, dailySummaries.value.length)} trên ${dailySummaries.value.length} ngày`
})

watch(searchQuery, () => {
  currentPage.value = 1
})

watch([dateSearchMode, dateFrom, dateTo], () => {
  currentPage.value = 1
})

watch(historyPeriod, () => {
  currentPage.value = 1
})

watch(totalPages, (pages) => {
  if (currentPage.value > pages) currentPage.value = pages
})

watch(dailySummaryPages, (pages) => {
  if (historyPeriod.value === 'day' && currentPage.value > pages) currentPage.value = pages
})

watch(todayTotalPages, (pages) => {
  if (todayPage.value > pages) todayPage.value = pages
})

async function submit() {
  const raw = input.value.trim()
  if (!raw) return
  const amount = Math.abs(Number(raw.replace(/[, ]/g, '')))
  if (Number.isNaN(amount) || amount === 0) {
    error.value = 'Nhập số dạng -25000 hoặc +30000'
    return
  }
  if (!selectedAccountType.value) {
    error.value = 'Chọn nguồn tiền trước khi ghi sổ'
    return
  }
  error.value = ''
  try {
    const created = await addEntry(
      amount * entryDirection.value,
      note.value.trim() || null,
      selectedAccountType.value,
      selectedTag.value,
      'transaction',
      countsTowardDaily.value
    )
    entries.value = [created, ...entries.value]
    input.value = ''
    note.value = ''
    selectedTag.value = null
    entryDirection.value = -1
    countsTowardDaily.value = true
    currentPage.value = 1
    todayPage.value = 1
  } catch (e) {
    error.value = 'Không lưu được. Thử lại.'
  }
}

function startBalanceEdit() {
  if (!selectedAccountType.value) {
    error.value = 'Chọn nguồn tiền trước khi điều chỉnh số dư'
    return
  }
  balanceInput.value = String(balancesByAccount.value[selectedAccountType.value])
  editingBalance.value = true
  error.value = ''
}

function cancelBalanceEdit() {
  editingBalance.value = false
  balanceInput.value = ''
}

function openTagModal() {
  error.value = ''
  tagInput.value = ''
  editingTagId.value = null
  editingTagName.value = ''
  tagModalOpen.value = true
}

function closeTagModal() {
  tagModalOpen.value = false
  tagInput.value = ''
  editingTagId.value = null
  editingTagName.value = ''
}

function startTagEdit(tag) {
  editingTagId.value = tag.id
  editingTagName.value = tag.name
}

function cancelTagEdit() {
  editingTagId.value = null
  editingTagName.value = ''
}

function validateTagName(name, excludeId = null) {
  const trimmedName = name.trim()
  if (!trimmedName) {
    error.value = 'Nhập tên thẻ'
    return null
  }
  if (tags.value.some((tag) => tag.id !== excludeId && normalizeSearch(tag.name) === normalizeSearch(trimmedName))) {
    error.value = 'Thẻ này đã tồn tại'
    return null
  }
  return trimmedName
}

async function submitTag() {
  const name = validateTagName(tagInput.value)
  if (!name) return
  error.value = ''
  try {
    const createdTags = await addTags([name])
    tags.value = [...tags.value, ...createdTags].sort((a, b) => a.name.localeCompare(b.name, 'vi'))
    tagInput.value = ''
  } catch (e) {
    error.value = 'Không thể thêm thẻ. Thử lại.'
  }
}

async function saveTag(tag) {
  const name = validateTagName(editingTagName.value, tag.id)
  if (!name) return
  error.value = ''
  try {
    const updatedTag = await updateTag(tag.id, name)
    const oldName = tag.name
    tags.value = tags.value.map((item) => item.id === updatedTag.id ? updatedTag : item)
      .sort((a, b) => a.name.localeCompare(b.name, 'vi'))
    if (selectedTag.value === oldName) selectedTag.value = updatedTag.name
    cancelTagEdit()
  } catch (e) {
    error.value = 'Không thể sửa thẻ. Thử lại.'
  }
}

async function removeTag(tag) {
  if (!window.confirm(`Xoá thẻ “${tag.name}”? Các giao dịch đã ghi vẫn giữ nguyên tên thẻ.`)) return
  error.value = ''
  try {
    await deleteTag(tag.id)
    tags.value = tags.value.filter((item) => item.id !== tag.id)
    if (selectedTag.value === tag.name) selectedTag.value = null
    if (editingTagId.value === tag.id) cancelTagEdit()
  } catch (e) {
    error.value = 'Không thể xoá thẻ. Thử lại.'
  }
}

async function saveBalance() {
  const raw = balanceInput.value.trim()
  const targetBalance = Number(raw.replace(/[, ]/g, ''))
  if (!raw || Number.isNaN(targetBalance)) {
    error.value = 'Nhập số dư hợp lệ'
    return
  }

  if (!selectedAccountType.value) {
    error.value = 'Chọn nguồn tiền trước khi điều chỉnh số dư'
    return
  }

  const adjustment = targetBalance - balancesByAccount.value[selectedAccountType.value]
  if (adjustment === 0) {
    cancelBalanceEdit()
    return
  }

  error.value = ''
  savingBalance.value = true
  try {
    const created = await addEntry(
      adjustment,
      'Điều chỉnh số dư',
      selectedAccountType.value,
      null,
      'adjustment'
    )
    entries.value = [created, ...entries.value]
    cancelBalanceEdit()
    currentPage.value = 1
    todayPage.value = 1
  } catch (e) {
    error.value = 'Không cập nhật được số dư. Thử lại.'
  } finally {
    savingBalance.value = false
  }
}

function requestRemove(entry) {
  if (activeView.value !== 'today' || !isSameUtcDay(entry.created_at, new Date())) {
    error.value = 'Chỉ có thể xoá giao dịch hôm nay trong tab Hôm nay.'
    return
  }
  confirmingEntry.value = entry
}

function openDebtManager() {
  error.value = ''
  debtManagerOpen.value = true
}

function closeDebtManager() {
  debtManagerOpen.value = false
}

async function createDebt(payload) {
  error.value = ''
  try {
    await createDebtAccount(payload.name, payload.note, payload.amount, payload.plans)
    await load()
    closeDebtManager()
  } catch (e) {
    error.value = 'Không thể tạo khoản nợ. Vui lòng thử lại.'
  }
}

async function increaseDebt(payload) {
  error.value = ''
  try {
    await addDebtIncrease(payload.debtId, payload.amount, payload.note, payload.plans)
    await load()
  } catch (e) {
    error.value = 'Không thể ghi phát sinh nợ. Vui lòng thử lại.'
  }
}

async function submitDebtPayment(payload) {
  error.value = ''
  try {
    await payDebt(payload.debtId, payload.amount, payload.accountType, payload.note)
    await load()
  } catch (e) {
    error.value = 'Không thể thanh toán nợ. Kiểm tra số dư nợ rồi thử lại.'
  }
}

function cancelRemove() {
  confirmingEntry.value = null
}

async function confirmRemove() {
  const entry = confirmingEntry.value
  if (!entry) return

  confirmingEntry.value = null
  entries.value = entries.value.filter((e) => e.id !== entry.id)
  try {
    await deleteEntry(entry.id)
  } catch (e) {
    error.value = 'Không xoá được trên máy chủ.'
    load()
  }
}

function fmt(n) {
  return new Intl.NumberFormat('vi-VN').format(n)
}

function isCountedTowardDaily(entry) {
  return entry.entry_type !== 'adjustment' && entry.counts_toward_daily !== false
}

function accountLabel(accountType) {
  return accountTypes.find((account) => account.value === accountType)?.label || 'Tiền mặt'
}

function formatDayLabel(key) {
  const [year, month, day] = key.split('-').map(Number)
  return new Intl.DateTimeFormat('vi-VN', { weekday: 'long', day: '2-digit', month: '2-digit', timeZone: 'UTC' })
    .format(new Date(Date.UTC(year, month - 1, day)))
}

function formatWeekday(key) {
  const [year, month, day] = key.split('-').map(Number)
  return new Intl.DateTimeFormat('vi-VN', { weekday: 'short', timeZone: 'UTC' })
    .format(new Date(Date.UTC(year, month - 1, day)))
}

function openDetails(rows, title) {
  detailRows.value = rows
  detailTitle.value = title
  detailPage.value = 1
}

function closeDetails() {
  detailRows.value = []
  detailTitle.value = ''
}

function openEntryDetail(row) {
  selectedEntryDetail.value = row
}

function closeEntryDetail() {
  selectedEntryDetail.value = null
}

function resetDateSearch() {
  dateFrom.value = ''
  dateTo.value = ''
}

function toggleBalances() {
  balancesHidden.value = !balancesHidden.value
  try {
    localStorage.setItem('dmoney-balances-hidden', String(balancesHidden.value))
  } catch (e) {
    // Việc ẩn/hiện vẫn hoạt động trong phiên hiện tại.
  }
}

function setAppearance(value) {
  appearance.value = value
  try {
    localStorage.setItem('dmoney-appearance', value)
  } catch (e) {
    // Giao diện vẫn áp dụng trong phiên hiện tại.
  }
}

function closeDailyInfo() {
  dailyInfoOpen.value = false
  clearTimeout(dailyInfoTimer)
}

function toggleDailyInfo() {
  if (dailyInfoOpen.value) {
    closeDailyInfo()
    return
  }
  dailyInfoOpen.value = true
  clearTimeout(dailyInfoTimer)
  dailyInfoTimer = setTimeout(closeDailyInfo, 3000)
}

function handleOutsidePointerDown(event) {
  if (dailyInfoOpen.value && !dailyInfoRef.value?.contains(event.target)) closeDailyInfo()
}

function handleKeydown(event) {
  if (event.key !== 'Escape') return
  if (dailyInfoOpen.value) closeDailyInfo()
  else if (selectedEntryDetail.value) closeEntryDetail()
  else if (detailTitle.value) closeDetails()
}

const detailTotalPages = computed(() => Math.max(1, Math.ceil(detailRows.value.length / pageSize)))
const paginatedDetailRows = computed(() => detailRows.value.slice((detailPage.value - 1) * pageSize, detailPage.value * pageSize))
const detailVisibleRange = computed(() => {
  if (!detailRows.value.length) return ''
  const start = (detailPage.value - 1) * pageSize + 1
  return `${start}–${Math.min(start + pageSize - 1, detailRows.value.length)} trên ${detailRows.value.length} giao dịch`
})
</script>

<template>
  <div v-if="authLoading" class="auth-loading">Đang kiểm tra đăng nhập…</div>
  <div v-else-if="localAuthError" class="auth-loading auth-error" role="alert">{{ localAuthError }}</div>
  <Login v-else-if="!session" />
  <div v-else class="page" :class="`appearance-${appearance}`">
    <div class="passbook">
      <div class="spine">
        <span v-for="i in 14" :key="i" class="hole"></span>
      </div>

      <div class="sheet">
        <LedgerHeader
          :current-date="currentDate"
          :is-local-environment="isLocalEnvironment"
          :balances-hidden="balancesHidden"
          :current-balance="currentBalance"
          :balances-by-account="balancesByAccount"
          :balance-account-types="balanceAccountTypes"
          :current-month-debt="currentMonthDebt"
          :current-debt="currentDebt"
          :format-amount="fmt"
          @open-settings="settingsOpen = true"
          @toggle-balances="toggleBalances"
          @start-balance-edit="startBalanceEdit"
          @open-debt-manager="openDebtManager"
        />
        <EntryForm
          v-model:input="input"
          v-model:note="note"
          v-model:selected-account-type="selectedAccountType"
          v-model:selected-tag="selectedTag"
          v-model:entry-direction="entryDirection"
          v-model:counts-toward-daily="countsTowardDaily"
          :account-types="accountTypes"
          :tags="tags"
          @submit="submit"
        />
        <form v-if="editingBalance" class="balance-form" @submit.prevent="saveBalance">
          <label for="balance-input">Đặt số dư hiện tại</label>
          <input
            id="balance-input"
            v-model="balanceInput"
            class="amount-input"
            type="text"
            inputmode="decimal"
            aria-label="Số dư hiện tại"
          />
          <button type="submit" class="save-balance-btn" :disabled="savingBalance">
            {{ savingBalance ? 'Đang lưu…' : 'Lưu số dư' }}
          </button>
          <button type="button" class="cancel-balance-btn" :disabled="savingBalance" @click="cancelBalanceEdit">
            Huỷ
          </button>
          <p class="balance-help">Chênh lệch sẽ được ghi vào sổ để số dư luôn tính luỹ kế.</p>
        </form>
        <p v-if="error" class="error">{{ error }}</p>

        <nav class="view-tabs" aria-label="Chuyển màn hình">
          <button type="button" :class="{ active: activeView === 'today' }" @click="activeView = 'today'">
            Hôm nay
          </button>
          <button type="button" :class="{ active: activeView === 'history' }" @click="activeView = 'history'">
            Lịch sử
          </button>
        </nav>

        <div class="ledger" v-if="!loading">
          <TodayPage
            v-if="activeView === 'today'"
            v-model:page="todayPage"
            :daily-balance="dailyBalance"
            :daily-income="dailyIncome"
            :daily-expense="dailyExpense"
            :today-rows="todayRows"
            :paginated-rows="paginatedTodayRows"
            :total-pages="todayTotalPages"
            :visible-range="todayVisibleRange"
            :page-size="pageSize"
            :format-amount="fmt"
            :format-time="fmtTime"
            :account-label="accountLabel"
            @request-remove="requestRemove"
          />


          <HistoryPage
            v-else
            v-model:history-period="historyPeriod"
            v-model:search-query="searchQuery"
            v-model:date-search-mode="dateSearchMode"
            v-model:date-from="dateFrom"
            v-model:date-to="dateTo"
            v-model:current-page="currentPage"
            :entries="entries"
            :history-rows="historyRows"
            :daily-summaries="dailySummaries"
            :paginated-daily-summaries="paginatedDailySummaries"
            :chart-buckets="chartBuckets"
            :chart-max="chartMax"
            :chart-income-total="chartIncomeTotal"
            :chart-expense-total="chartExpenseTotal"
            :daily-summary-pages="dailySummaryPages"
            :daily-summary-range="dailySummaryRange"
            :page-size="pageSize"
            :format-amount="fmt"
            @reset-date-search="resetDateSearch"
            @open-details="openDetails"
          />

        </div>
        <div v-else class="loading">Đang mở sổ…</div>
      </div>
    </div>

    <AppDialogs
      v-model:tag-input="tagInput"
      v-model:editing-tag-name="editingTagName"
      v-model:detail-page="detailPage"
      :confirming-entry="confirmingEntry"
      :tag-modal-open="tagModalOpen"
      :tags="tags"
      :editing-tag-id="editingTagId"
      :detail-title="detailTitle"
      :paginated-detail-rows="paginatedDetailRows"
      :detail-rows="detailRows"
      :detail-total-pages="detailTotalPages"
      :detail-visible-range="detailVisibleRange"
      :page-size="pageSize"
      :selected-entry-detail="selectedEntryDetail"
      :balances-hidden="balancesHidden"
      :error="error"
      :format-amount="fmt"
      :format-time="fmtTime"
      :account-label="accountLabel"
      @cancel-remove="cancelRemove"
      @confirm-remove="confirmRemove"
      @close-tag-modal="closeTagModal"
      @submit-tag="submitTag"
      @start-tag-edit="startTagEdit"
      @save-tag="saveTag"
      @cancel-tag-edit="cancelTagEdit"
      @remove-tag="removeTag"
      @close-details="closeDetails"
      @open-entry-detail="openEntryDetail"
      @close-entry-detail="closeEntryDetail"
    />
    <DebtManager
      :open="debtManagerOpen"
      :debts="debts"
      :balances-hidden="balancesHidden"
      :format-amount="fmt"
      :error="error"
      @close="closeDebtManager"
      @create="createDebt"
      @increase="increaseDebt"
      @pay="submitDebtPayment"
    />
    <SettingsModal
      :open="settingsOpen"
      :is-local-environment="isLocalEnvironment"
      :appearance="appearance"
      @close="settingsOpen = false"
      @update:appearance="setAppearance"
      @open-tag-manager="settingsOpen = false; openTagModal()"
      @sign-out="handleSignOut"
    />

  </div>
</template>
