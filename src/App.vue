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
import EventsPage from './components/EventsPage.vue'
import MonthlyReport from './components/MonthlyReport.vue'
import ToastStack from './components/ToastStack.vue'
import { addDays, dateKey, formatDate, isSameDay, browserTimeZone, monthKey, weekStartKey } from './utils/date'
import { formatMoney, parseMoney, parseSignedMoney } from './utils/money'
import { buildMonthlyReport } from './utils/report'
import { fetchEntries, addEntry, deleteEntry, fetchTags, addTags, updateTag, deleteTag, fetchDebtData, createDebtAccount, addDebtIncrease, payDebt, updateDebtAccount, deleteDebtAccount, saveDebtPlan, deleteDebtPlan, fetchEvents, addEvent, deleteEvent, fetchEventEntries, signInAnonymously, signOut, getSession, onAuthStateChange } from './supabase'

const entries = ref([])
const tags = ref([])
const debtAccounts = ref([])
const debtEntries = ref([])
const debtPlans = ref([])
const events = ref([])
const selectedEvent = ref(null)
const eventName = ref('')
const eventStart = ref('')
const eventEnd = ref('')
const eventNote = ref('')
const eventAmount = ref('')
const eventEntryNote = ref('')
const eventEntryDate = ref('')
const eventDirection = ref(-1)
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
const reportMonth = ref(monthKey(new Date(), browserTimeZone()))
const historyPeriod = ref('month')
const historyMode = ref('calendar')
const calendarAnchorKey = ref('')
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
const dayResetTimeZone = ref(browserTimeZone())
const moneyUnit = ref('k')
const toasts = ref([])
const actionLoading = ref({})
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
let loadVersion = 0
let toastId = 0

function pushToast(message, type = 'error') {
  const id = ++toastId
  toasts.value.push({ id, message, type })
  setTimeout(() => dismissToast(id), 4500)
}

function notifyError(message) {
  error.value = ''
  pushToast(message)
}

function dismissToast(id) {
  toasts.value = toasts.value.filter((toast) => toast.id !== id)
}

function setActionLoading(key, value) {
  actionLoading.value = { ...actionLoading.value, [key]: value }
}

onMounted(async () => {
  document.addEventListener('keydown', handleKeydown)
  document.addEventListener('pointerdown', handleOutsidePointerDown)
  calendarAnchorKey.value = utcDateKey(new Date())
  try {
    balancesHidden.value = localStorage.getItem('dmoney-balances-hidden') === 'true'
    const savedAppearance = localStorage.getItem('dmoney-appearance')
    if (['ledger', 'modern', 'midnight', 'breeze'].includes(savedAppearance)) appearance.value = savedAppearance
    const savedDayResetTimeZone = localStorage.getItem('dmoney-day-reset-time-zone')
    if (savedDayResetTimeZone) dayResetTimeZone.value = savedDayResetTimeZone
    const savedMoneyUnit = localStorage.getItem('dmoney-money-unit')
    if (savedMoneyUnit === 'k' || savedMoneyUnit === 'vnd') moneyUnit.value = savedMoneyUnit
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
    notifyError('Không kiểm tra được trạng thái đăng nhập. Vui lòng thử lại.')
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
      events.value = []
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
  const version = ++loadVersion
  loading.value = true
  try {
    const [loadedEntries, loadedTags, loadedDebtData, loadedEvents] = await Promise.all([fetchEntries(), fetchTags(), fetchDebtData(), fetchEvents()])
    if (version !== loadVersion) return
    entries.value = loadedEntries
    tags.value = loadedTags
    debtAccounts.value = loadedDebtData.accounts
    debtEntries.value = loadedDebtData.entries
    debtPlans.value = loadedDebtData.plans
    events.value = await Promise.all(loadedEvents.map(async (event) => ({ ...event, entries: await fetchEventEntries(event.id) })))
    await seedDefaultTags()
  } catch (e) {
    notifyError('Không tải được sổ. Kiểm tra kết nối Supabase.')
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
    notifyError('Không thể đăng xuất. Vui lòng thử lại.')
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
const currentDate = computed(() => new Intl.DateTimeFormat('vi-VN', {
  weekday: 'long',
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
  timeZone: dayResetTimeZone.value
}).format(new Date()))

function utcDateKey(value) {
  return dateKey(value, dayResetTimeZone.value)
}

function isSameUtcDay(value, date) {
  return isSameDay(value, date, dayResetTimeZone.value)
}

function isInHistoryPeriod(value) {
  const rowKey = utcDateKey(value)
  const today = utcDateKey()

  if (historyPeriod.value === 'day') return true

  if (historyPeriod.value === 'week') {
    return rowKey >= weekStartKey(new Date(), dayResetTimeZone.value) && rowKey <= today
  }

  return rowKey.slice(0, 7) === monthKey(new Date(), dayResetTimeZone.value)
}

function isInCurrentMonth(value) {
  return utcDateKey(value).slice(0, 7) === monthKey(new Date(), dayResetTimeZone.value)
}

function fmtTime(value) {
  return formatDate(value, dayResetTimeZone.value, {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  })
}

function groupByDay(rows) {
  const groups = []
  let currentDay = null
  for (const row of rows) {
    const day = formatDate(row.created_at, dayResetTimeZone.value, {
      weekday: 'short', day: '2-digit', month: '2-digit'
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
const monthlyReport = computed(() => buildMonthlyReport(withBalance.value, reportMonth.value, utcDateKey, isCountedTowardDaily))
const reportMonthLabel = computed(() => {
  const [year, month] = reportMonth.value.split('-').map(Number)
  return new Intl.DateTimeFormat('vi-VN', { month: 'long', year: 'numeric', timeZone: 'UTC' })
    .format(new Date(Date.UTC(year, month - 1, 1)))
})
const reportCanMoveNext = computed(() => reportMonth.value < monthKey(new Date(), dayResetTimeZone.value))
const currentDebtMonth = computed(() => `${monthKey(new Date(), dayResetTimeZone.value)}-01`)
const debts = computed(() => {
  const entriesByDebt = new Map()
  const plansByDebt = new Map()
  for (const entry of debtEntries.value) {
    if (!entriesByDebt.has(entry.debt_id)) entriesByDebt.set(entry.debt_id, [])
    entriesByDebt.get(entry.debt_id).push(entry)
  }
  for (const plan of debtPlans.value) {
    if (!plansByDebt.has(plan.debt_id)) plansByDebt.set(plan.debt_id, [])
    plansByDebt.get(plan.debt_id).push(plan)
  }
  return debtAccounts.value.map((account) => {
  const entries = entriesByDebt.get(account.id) || []
  const plans = plansByDebt.get(account.id) || []
  const balance = entries.reduce((total, entry) => total + Number(entry.amount), 0)
  const monthPlanned = plans.filter((plan) => plan.month === currentDebtMonth.value).reduce((total, plan) => total + Number(plan.planned_amount), 0)
  const monthPaid = entries.filter((entry) => entry.entry_type === 'payment' && String(entry.occurred_at).slice(0, 7) === currentDebtMonth.value.slice(0, 7)).reduce((total, entry) => total + Math.abs(Number(entry.amount)), 0)
  return { ...account, entries, plans: plans.map((plan) => ({ month: plan.month, amount: Number(plan.planned_amount) })), balance, monthPlanned, monthPaid, monthRemaining: Math.max(0, monthPlanned - monthPaid) }
  }).filter((debt) => debt.balance > 0)
})
const owedDebts = computed(() => debts.value.filter((debt) => debt.debt_type !== 'lent'))
const currentDebt = computed(() => owedDebts.value.reduce((total, debt) => total + debt.balance, 0))
const currentMonthDebt = computed(() => owedDebts.value.reduce((total, debt) => total + debt.monthRemaining, 0))
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
  let start = utcDateKey(now)
  const buckets = []
  let count = historyPeriod.value === 'week' ? 7 : Number(`${monthKey(now, dayResetTimeZone.value)}-01`.slice(8, 10))
  if (historyPeriod.value !== 'week') {
    const [year, month] = monthKey(now, dayResetTimeZone.value).split('-').map(Number)
    count = new Date(Date.UTC(year, month, 0)).getUTCDate()
  }
  if (hasDateSearch.value) {
    const firstKey = dateFrom.value || utcDateKey(historyRows.value.at(-1)?.created_at || now)
    const lastKey = dateTo.value || utcDateKey(historyRows.value[0]?.created_at || now)
    const [startYear, startMonth, startDay] = firstKey.split('-').map(Number)
    const [endYear, endMonth, endDay] = lastKey.split('-').map(Number)
    start = `${startYear}-${String(startMonth).padStart(2, '0')}-${String(startDay).padStart(2, '0')}`
    const end = `${endYear}-${String(endMonth).padStart(2, '0')}-${String(endDay).padStart(2, '0')}`
    count = Math.max(1, Math.round((new Date(`${end}T00:00:00Z`) - new Date(`${start}T00:00:00Z`)) / 86400000) + 1)
  } else if (historyPeriod.value === 'week') {
    start = weekStartKey(now, dayResetTimeZone.value)
  } else {
    start = `${monthKey(now, dayResetTimeZone.value)}-01`
  }
  for (let index = 0; index < count; index += 1) {
    const key = addDays(start, index)
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

const calendarCells = computed(() => {
  const now = new Date(`${calendarAnchorKey.value || utcDateKey(new Date())}T12:00:00Z`)
  let keys = []
  if (historyPeriod.value === 'day') {
    const currentMonth = monthKey(now, dayResetTimeZone.value)
    const [year, month] = currentMonth.split('-').map(Number)
    const days = new Date(Date.UTC(year, month, 0)).getUTCDate()
    keys = Array.from({ length: days }, (_, index) => `${currentMonth}-${String(index + 1).padStart(2, '0')}`)
  } else if (historyPeriod.value === 'week') {
    const start = weekStartKey(now, dayResetTimeZone.value)
    keys = Array.from({ length: 7 }, (_, index) => addDays(start, index))
  } else {
    const year = Number(utcDateKey(now).slice(0, 4))
    keys = Array.from({ length: 12 }, (_, index) => `${year}-${String(index + 1).padStart(2, '0')}`)
  }
  return keys.map((key) => {
    const rows = withBalance.value.filter((row) => {
      const rowKey = utcDateKey(row.created_at)
      return historyPeriod.value === 'month' ? rowKey.startsWith(key) : rowKey === key
    }).filter((row) => matchesDateSearch(row) && (!searchQuery.value || filteredRows.value.some((item) => item.id === row.id)))
    const income = rows.filter((row) => isCountedTowardDaily(row) && Number(row.amount) > 0).reduce((sum, row) => sum + Number(row.amount), 0)
    const expense = rows.filter((row) => isCountedTowardDaily(row) && Number(row.amount) < 0).reduce((sum, row) => sum + Math.abs(Number(row.amount)), 0)
    const [year, month, day] = key.split('-').map(Number)
    const label = historyPeriod.value === 'month' ? new Intl.DateTimeFormat('vi-VN', { month: 'long' }).format(new Date(Date.UTC(year, month - 1, 1))) : (historyPeriod.value === 'week' ? formatWeekday(key) : String(day))
    const firstDay = historyPeriod.value === 'day'
      ? (new Date(Date.UTC(year, month - 1, 1)).getUTCDay() + 6) % 7
      : 0
    return { key, label, dayNumber: historyPeriod.value === 'day' ? day : null, rows, income, expense, net: income - expense, isToday: key === utcDateKey(now), firstDay }
  })
})
const calendarWeekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
const calendarTitle = computed(() => {
  const anchor = new Date(`${calendarAnchorKey.value || utcDateKey(new Date())}T12:00:00Z`)
  if (historyPeriod.value === 'month') return String(anchor.getUTCFullYear())
  if (historyPeriod.value === 'week') {
    const start = weekStartKey(anchor, dayResetTimeZone.value)
    return `${formatDayLabel(start)} – ${formatDayLabel(addDays(start, 6))}`
  }
  return new Intl.DateTimeFormat('vi-VN', { month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(Date.UTC(anchor.getUTCFullYear(), anchor.getUTCMonth(), 1)))
})
const calendarCanNext = computed(() => calendarAnchorKey.value < utcDateKey(new Date()))
function moveCalendar(direction) {
  const anchor = new Date(`${calendarAnchorKey.value || utcDateKey(new Date())}T12:00:00Z`)
  if (historyPeriod.value === 'month') anchor.setUTCFullYear(anchor.getUTCFullYear() + direction)
  else if (historyPeriod.value === 'week') calendarAnchorKey.value = addDays(calendarAnchorKey.value, direction * 7)
  else anchor.setUTCMonth(anchor.getUTCMonth() + direction)
  if (historyPeriod.value !== 'week') calendarAnchorKey.value = `${anchor.getUTCFullYear()}-${String(anchor.getUTCMonth() + 1).padStart(2, '0')}-01`
  if (calendarAnchorKey.value > utcDateKey(new Date())) calendarAnchorKey.value = utcDateKey(new Date())
}

function moveReportMonth(direction) {
  const [year, month] = reportMonth.value.split('-').map(Number)
  const next = new Date(Date.UTC(year, month - 1 + direction, 1))
  const nextMonth = `${next.getUTCFullYear()}-${String(next.getUTCMonth() + 1).padStart(2, '0')}`
  if (nextMonth <= monthKey(new Date(), dayResetTimeZone.value)) reportMonth.value = nextMonth
}

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
  const amount = parseMoney(raw, moneyUnit.value)
  if (!amount) {
    notifyError('Nhập số dạng -25000 hoặc +30000')
    return
  }
  if (!selectedAccountType.value) {
    notifyError('Chọn nguồn tiền trước khi ghi sổ')
    return
  }
  error.value = ''
  setActionLoading('entry', true)
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
    notifyError('Không lưu được. Thử lại.')
    pushToast(error.value)
  } finally {
    setActionLoading('entry', false)
  }
}

function startBalanceEdit() {
  if (!selectedAccountType.value) {
    notifyError('Chọn nguồn tiền trước khi điều chỉnh số dư')
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
    notifyError('Nhập tên thẻ')
    return null
  }
  if (tags.value.some((tag) => tag.id !== excludeId && normalizeSearch(tag.name) === normalizeSearch(trimmedName))) {
    notifyError('Thẻ này đã tồn tại')
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
    notifyError('Không thể thêm thẻ. Thử lại.')
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
    notifyError('Không thể sửa thẻ. Thử lại.')
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
    notifyError('Không thể xoá thẻ. Thử lại.')
  }
}

async function saveBalance() {
  const raw = balanceInput.value.trim()
  const targetBalance = parseSignedMoney(raw, moneyUnit.value)
  if (targetBalance === null) {
    notifyError('Nhập số dư hợp lệ')
    return
  }

  if (!selectedAccountType.value) {
    notifyError('Chọn nguồn tiền trước khi điều chỉnh số dư')
    return
  }

  const adjustment = targetBalance - balancesByAccount.value[selectedAccountType.value]
  if (adjustment === 0) {
    cancelBalanceEdit()
    return
  }

  error.value = ''
  savingBalance.value = true
  setActionLoading('balance', true)
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
    notifyError('Không cập nhật được số dư. Thử lại.')
    pushToast(error.value)
  } finally {
    savingBalance.value = false
    setActionLoading('balance', false)
  }
}

function requestRemove(entry) {
  if (activeView.value !== 'today' || !isSameUtcDay(entry.created_at, new Date())) {
    notifyError('Chỉ có thể xoá giao dịch hôm nay trong tab Hôm nay.')
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
    await createDebtAccount(payload.name, payload.note, payload.amount, payload.plans, payload.debtType, payload.dueDate)
    await load()
    closeDebtManager()
  } catch (e) {
    notifyError('Không thể tạo khoản nợ. Vui lòng thử lại.')
  }
}

async function increaseDebt(payload) {
  error.value = ''
  try {
    await addDebtIncrease(payload.debtId, payload.amount, payload.note, payload.plans)
    await load()
  } catch (e) {
    notifyError('Không thể ghi phát sinh nợ. Vui lòng thử lại.')
  }
}

async function submitDebtPayment(payload) {
  error.value = ''
  try {
    await payDebt(payload.debtId, payload.amount, payload.accountType, payload.note)
    await load()
  } catch (e) {
    notifyError('Không thể thanh toán nợ. Kiểm tra số dư nợ rồi thử lại.')
  }
}

async function editDebt(payload) {
  error.value = ''
  try {
    await updateDebtAccount(payload.debtId, payload.name, payload.note)
    await load()
  } catch (e) {
    notifyError('Không thể cập nhật khoản nợ. Vui lòng thử lại.')
  }
}

async function removeDebt(payload) {
  error.value = ''
  try {
    await deleteDebtAccount(payload.debtId)
    await load()
  } catch (e) {
    notifyError('Không thể xoá khoản nợ. Vui lòng thử lại.')
  }
}

async function updateDebtPlan(payload) {
  error.value = ''
  try {
    await saveDebtPlan(payload.debtId, payload.month, payload.amount)
    await load()
  } catch (e) {
    notifyError('Không thể lưu lịch trả. Vui lòng thử lại.')
  }
}

async function removeDebtPlan(payload) {
  error.value = ''
  try {
    await deleteDebtPlan(payload.debtId, payload.month)
    await load()
  } catch (e) {
    notifyError('Không thể xoá lịch trả. Vui lòng thử lại.')
  }
}

function cancelRemove() {
  confirmingEntry.value = null
}

async function confirmRemove() {
  const entry = confirmingEntry.value
  if (!entry) return

  confirmingEntry.value = null
  setActionLoading('delete-entry', entry.id)
  entries.value = entries.value.filter((e) => e.id !== entry.id)
  try {
    await deleteEntry(entry.id)
  } catch (e) {
    notifyError('Không xoá được trên máy chủ.')
    pushToast(error.value)
    await load()
  } finally {
    setActionLoading('delete-entry', false)
  }
}

function fmt(n) {
  return formatMoney(n, moneyUnit.value)
}

function setMoneyUnit(value) {
  moneyUnit.value = value
  try {
    localStorage.setItem('dmoney-money-unit', value)
  } catch (e) {
    // Vẫn áp dụng trong phiên hiện tại nếu localStorage bị chặn.
  }
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

async function createEvent() {
  if (!eventName.value.trim() || !eventStart.value || !eventEnd.value || eventEnd.value < eventStart.value) return notifyError('Kiểm tra tên và khoảng thời gian sự kiện')
  try {
    const created = await addEvent(eventName.value.trim(), eventStart.value, eventEnd.value, eventNote.value.trim() || null)
    events.value = [{ ...created, entries: [] }, ...events.value]
    eventName.value = ''; eventStart.value = ''; eventEnd.value = ''; eventNote.value = ''
  } catch (e) { notifyError('Không thể tạo sự kiện. Thử lại.') }
}

async function addEventEntry() {
  const amount = parseMoney(eventAmount.value.trim(), moneyUnit.value)
  if (!amount || !selectedEvent.value || !eventEntryDate.value) return notifyError('Nhập số tiền và ngày giao dịch hợp lệ')
  if (eventEntryDate.value < selectedEvent.value.start_date || eventEntryDate.value > selectedEvent.value.end_date) return notifyError('Ngày giao dịch phải nằm trong thời gian sự kiện')
  try {
    const created = await addEntry(amount * eventDirection.value, eventEntryNote.value.trim() || null, 'cash', null, 'transaction', false, selectedEvent.value.id, `${eventEntryDate.value}T12:00:00.000Z`)
    events.value = events.value.map((event) => event.id === selectedEvent.value.id ? { ...event, entries: [created, ...(event.entries || [])] } : event)
    entries.value = [created, ...entries.value]
    eventAmount.value = ''; eventEntryNote.value = ''; eventDirection.value = -1
  } catch (e) { notifyError('Không thể lưu giao dịch sự kiện. Thử lại.') }
}

async function removeEvent(event) {
  if (!window.confirm(`Xoá sự kiện “${event.name}” và các giao dịch bên trong?`)) return
  try { await deleteEvent(event.id); events.value = events.value.filter((item) => item.id !== event.id); if (selectedEvent.value?.id === event.id) selectedEvent.value = null; await load() } catch (e) { notifyError('Không thể xoá sự kiện.') }
}

function requestRemoveDetail() {
  if (!selectedEntryDetail.value) return
  const entry = selectedEntryDetail.value
  selectedEntryDetail.value = null
  confirmingEntry.value = entry
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

function setDayResetTimeZone(value) {
  dayResetTimeZone.value = value
  try {
    localStorage.setItem('dmoney-day-reset-time-zone', value)
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
          :loading="actionLoading.entry"
          :money-unit="moneyUnit"
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
          <button type="submit" class="save-balance-btn" :disabled="savingBalance || actionLoading.balance">
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
          <button type="button" :class="{ active: activeView === 'report' }" @click="activeView = 'report'">
            Báo cáo
          </button>
          <button type="button" :class="{ active: activeView === 'events' }" @click="activeView = 'events'">
            Sự kiện
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
            :deleting-entry-id="actionLoading['delete-entry']"
            @request-remove="requestRemove"
            @open-entry-detail="openEntryDetail"
          />


          <HistoryPage
            v-else-if="activeView === 'history'"
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
            :history-mode="historyMode"
            :calendar-cells="calendarCells"
            :calendar-weekdays="calendarWeekdays"
            :calendar-title="calendarTitle"
            :calendar-can-next="calendarCanNext"
            @reset-date-search="resetDateSearch"
            @open-details="openDetails"
            @update:history-mode="historyMode = $event"
            @move-calendar="moveCalendar"
          />

          <MonthlyReport
            v-else-if="activeView === 'report'"
            :month-label="reportMonthLabel"
            :can-move-next="reportCanMoveNext"
            :report="monthlyReport"
            :format-amount="fmt"
            @move-month="moveReportMonth"
          />

          <EventsPage
            v-else
            v-model:selected-event="selectedEvent"
            v-model:event-name="eventName"
            v-model:event-start="eventStart"
            v-model:event-end="eventEnd"
            v-model:event-note="eventNote"
            v-model:event-amount="eventAmount"
            v-model:event-entry-note="eventEntryNote"
            v-model:event-entry-date="eventEntryDate"
            v-model:event-direction="eventDirection"
            :events="events"
            :format-amount="fmt"
            @create-event="createEvent"
            @add-event-entry="addEventEntry"
            @delete-event="removeEvent"
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
      :money-unit="moneyUnit"
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
      @request-remove-detail="requestRemoveDetail"
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
      @edit="editDebt"
      @delete="removeDebt"
      @save-plan="updateDebtPlan"
      @delete-plan="removeDebtPlan"
    />
    <SettingsModal
      :open="settingsOpen"
      :is-local-environment="isLocalEnvironment"
      :appearance="appearance"
          :day-reset-time-zone="dayResetTimeZone"
          :money-unit="moneyUnit"
      @close="settingsOpen = false"
      @update:appearance="setAppearance"
          @update:day-reset-time-zone="setDayResetTimeZone"
          @update:money-unit="setMoneyUnit"
      @open-tag-manager="settingsOpen = false; openTagModal()"
      @sign-out="handleSignOut"
    />
    <ToastStack :toasts="toasts" @dismiss="dismissToast" />

  </div>
</template>
