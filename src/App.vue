<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import Login from './components/Login.vue'
import { fetchEntries, addEntry, deleteEntry, fetchTags, addTags, updateTag, deleteTag, fetchDebts, addDebt, deleteDebt, signInAnonymously, signOut, getSession, onAuthStateChange } from './supabase'

const entries = ref([])
const tags = ref([])
const debts = ref([])
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
const debtInput = ref('')
const debtNote = ref('')
const debtDirection = ref(1)
const debtType = ref('owed')
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
const confirmingDebt = ref(null)
const debtDetailType = ref(null)
const debtModalOpen = ref(false)
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
      debts.value = []
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
    const [loadedEntries, loadedTags, loadedDebts] = await Promise.all([fetchEntries(), fetchTags(), fetchDebts()])
    entries.value = loadedEntries
    tags.value = loadedTags
    debts.value = loadedDebts
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
const owedDebts = computed(() => debts.value.filter((debt) => debt.debt_type !== 'lent'))
const lentDebts = computed(() => debts.value.filter((debt) => debt.debt_type === 'lent'))
const currentMonthDebt = computed(() => owedDebts.value
  .filter((debt) => isInCurrentMonth(debt.created_at))
  .reduce((total, debt) => total + Number(debt.amount), 0))
const currentDebt = computed(() => owedDebts.value.reduce((total, debt) => total + Number(debt.amount), 0))
const currentLent = computed(() => lentDebts.value.reduce((total, debt) => total + Number(debt.amount), 0))
const visibleDebtDetails = computed(() => debtDetailType.value === 'lent' ? lentDebts.value : owedDebts.value)
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

async function submitDebt() {
  const raw = debtInput.value.trim()
  const amount = Math.abs(Number(raw.replace(/[, ]/g, '')))
  if (!raw || Number.isNaN(amount) || amount === 0) {
    error.value = 'Nhập số nợ khác 0'
    return
  }
  error.value = ''
  try {
    const created = await addDebt(amount * debtDirection.value, debtNote.value.trim() || null, debtType.value)
    debts.value = [created, ...debts.value]
    debtInput.value = ''
    debtNote.value = ''
    debtDirection.value = 1
    debtType.value = 'owed'
    debtModalOpen.value = false
  } catch (e) {
    error.value = 'Không lưu được khoản nợ. Thử lại.'
  }
}

function openDebtModal() {
  error.value = ''
  debtModalOpen.value = true
}

function closeDebtModal() {
  debtModalOpen.value = false
}

function requestRemoveDebt(debt) {
  debtDetailType.value = null
  confirmingDebt.value = debt
}

function cancelRemoveDebt() {
  confirmingDebt.value = null
}

function closeDebtDetails() {
  debtDetailType.value = null
}

async function confirmRemoveDebt() {
  const debt = confirmingDebt.value
  if (!debt) return
  confirmingDebt.value = null
  const isLent = debt.debt_type === 'lent'
  const settlementAmount = Math.abs(Number(debt.amount)) * (isLent ? 1 : -1)
  const settlementNote = isLent
    ? `Thu hồi khoản cho nợ${debt.note ? `: ${debt.note}` : ''}`
    : `Thanh toán nợ${debt.note ? `: ${debt.note}` : ''}`
  let settlementEntry = null
  try {
    settlementEntry = await addEntry(settlementAmount, settlementNote, 'bank', null, 'transaction', false)
    await deleteDebt(debt.id)
    entries.value = [settlementEntry, ...entries.value]
    debts.value = debts.value.filter((item) => item.id !== debt.id)
    currentPage.value = 1
    todayPage.value = 1
  } catch (e) {
    if (settlementEntry) {
      try {
        await deleteEntry(settlementEntry.id)
      } catch (rollbackError) {
        await load()
      }
    }
    error.value = 'Không thể tất toán khoản nợ. Số dư và khoản nợ được giữ nguyên.'
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
  <div v-else class="page">
    <div class="passbook">
      <div class="spine">
        <span v-for="i in 14" :key="i" class="hole"></span>
      </div>

      <div class="sheet">
        <header class="head">
          <div class="head-text">
            <div class="head-meta">
              <p class="eyebrow">{{ currentDate }}</p>
              <button v-if="!isLocalEnvironment" type="button" class="sign-out-btn" @click="handleSignOut">Đăng xuất</button>
            </div>
            <h1>DMoney</h1>
          </div>
          <div class="balance-controls">
            <div class="balance-stamps" aria-label="Số dư theo nguồn tiền">
              <div class="balance-total" :class="{ negative: !balancesHidden && currentBalance < 0 }">
                <div class="balance-total-topline">
                  <span class="balance-total-label">Tổng số dư</span>
                  <div class="balance-actions">
                    <button
                      type="button"
                      class="balance-visibility-btn"
                      :aria-label="balancesHidden ? 'Hiện số dư' : 'Ẩn số dư'"
                      :aria-pressed="balancesHidden"
                      :title="balancesHidden ? 'Hiện số dư' : 'Ẩn số dư'"
                      @click="toggleBalances"
                    >
                      <svg v-if="balancesHidden" aria-hidden="true" viewBox="0 0 24 24">
                        <path d="M3 3l18 18M10.6 10.7a2 2 0 0 0 2.7 2.7M9.9 4.2A10.8 10.8 0 0 1 12 4c5.5 0 9 5.5 9 5.5a15.8 15.8 0 0 1-2.1 2.7M6.6 6.6A17.2 17.2 0 0 0 3 9.5S6.5 15 12 15c1 0 2-.2 2.8-.5" />
                      </svg>
                      <svg v-else aria-hidden="true" viewBox="0 0 24 24">
                        <path d="M3 9.5S6.5 4 12 4s9 5.5 9 5.5S17.5 15 12 15 3 9.5 3 9.5Z" />
                        <circle cx="12" cy="9.5" r="2.5" />
                      </svg>
                    </button>
                    <button
                      type="button"
                      class="edit-balance-btn"
                      aria-label="Điều chỉnh số dư"
                      title="Điều chỉnh số dư"
                      @click="startBalanceEdit"
                    >
                      <span aria-hidden="true">✎</span>
                    </button>
                  </div>
                </div>
                <strong class="balance-total-amount" :class="{ masked: balancesHidden }">
                  {{ balancesHidden ? '••••••' : fmt(currentBalance) }} <small>₫</small>
                </strong>
              </div>
              <div class="balance-source-stamps">
                <div
                  v-for="account in balanceAccountTypes"
                  :key="account.value"
                  class="balance-source"
                  :class="account.value"
                  :aria-label="balancesHidden ? `${account.label}: số dư đang được ẩn` : `${account.label}: ${fmt(balancesByAccount[account.value])} đồng`"
                >
                  <span class="balance-source-icon" aria-hidden="true"></span>
                  <span class="balance-source-label">{{ account.label }}</span>
                  <strong class="balance-source-amount" :class="{ negative: !balancesHidden && balancesByAccount[account.value] < 0, masked: balancesHidden }">
                    {{ balancesHidden ? '••••••' : fmt(balancesByAccount[account.value]) }} <small>₫</small>
                  </strong>
                </div>
              </div>
            </div>
            <section class="debt-card" aria-label="Theo dõi nợ">
              <button type="button" class="debt-summary debt-total-button" :aria-label="balancesHidden ? 'Đang cho nợ: số tiền đang được ẩn' : `Đang cho nợ: ${fmt(currentLent)} đồng`" @click="debtDetailType = 'lent'">
                <span>Đang cho nợ</span>
                <strong :class="{ masked: balancesHidden }">{{ balancesHidden ? '••••••' : fmt(currentLent) }} <small>₫</small></strong>
              </button>
              <button type="button" class="debt-summary debt-total-button" :aria-label="balancesHidden ? 'Nợ hiện tại: số tiền đang được ẩn' : `Nợ hiện tại: ${fmt(currentDebt)} đồng`" @click="debtDetailType = 'owed'">
                <span>Nợ hiện tại</span>
                <strong :class="{ masked: balancesHidden }">{{ balancesHidden ? '••••••' : fmt(currentDebt) }} <small>₫</small></strong>
              </button>
              <button type="button" class="debt-add-btn debt-open-btn" @click="openDebtModal">+ Ghi khoản nợ</button>
            </section>
          </div>
        </header>

        <form class="entry-form" @submit.prevent="submit">
          <div class="amount-row">
            <input
              v-model="input"
              class="amount-input"
              :class="entryDirection === -1 ? 'expense-input' : 'income-input'"
              type="text"
              inputmode="numeric"
              placeholder="Số tiền"
              aria-label="Số tiền"
            />
            <div class="entry-direction" aria-label="Loại giao dịch">
              <button type="button" :class="{ active: entryDirection === -1 }" @click="entryDirection = -1">− Chi</button>
              <button type="button" :class="{ active: entryDirection === 1 }" @click="entryDirection = 1">+ Thu</button>
            </div>
          </div>
          <div class="choice-group account-choice" role="group" aria-label="Nguồn tiền">
            <button
              v-for="account in accountTypes"
              :key="account.value"
              type="button"
              :class="{ active: selectedAccountType === account.value }"
              @click="selectedAccountType = account.value"
            >
              {{ account.label }}
            </button>
          </div>
          <div class="note-daily-row">
            <input
              v-model="note"
              class="note-input"
              type="text"
              placeholder="Note (tuỳ chọn)"
              aria-label="Ghi chú"
            />
            <div ref="dailyInfoRef" class="daily-toggle-control">
              <label class="daily-toggle">
                <span class="daily-toggle-text">Tính thu nhập ngày</span>
                <input v-model="countsTowardDaily" type="checkbox" role="switch" aria-label="Tính giao dịch vào thu nhập ngày" />
                <span class="toggle-track" aria-hidden="true"><span></span></span>
              </label>
            </div>
          </div>
          <fieldset class="choice-group tag-choice">
            <legend>Thẻ <span>(tuỳ chọn)</span><button type="button" class="manage-tags-btn" @click="openTagModal">Quản lý</button></legend>
            <button
              v-for="tag in tags"
              :key="tag.id"
              type="button"
              :class="{ active: selectedTag === tag.name }"
              @click="selectedTag = selectedTag === tag.name ? null : tag.name"
            >
              {{ tag.name }}
            </button>
          </fieldset>
          <button type="submit" class="add-btn">Ghi sổ</button>
        </form>
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
          <template v-if="activeView === 'today'">
            <div class="daily-balance">
              <span>Thu nhập ngày</span>
              <span class="daily-balance-values">
                <strong :class="dailyBalance < 0 ? 'neg' : 'pos'">
                  {{ dailyBalance < 0 ? '' : '+' }}{{ fmt(dailyBalance) }}
                </strong>
                <span class="daily-breakdown">
                  <small class="pos">Thu {{ fmt(dailyIncome) }}</small>
                  <span aria-hidden="true">·</span>
                  <small class="neg">Chi {{ fmt(dailyExpense) }}</small>
                </span>
              </span>
            </div>
            <div v-if="!todayRows.length" class="empty">
              Hôm nay chưa có giao dịch nào.
            </div>
            <div v-else class="day-group">
              <div class="day-label">
                <span>Giao dịch hôm nay</span>
                <span class="rule"></span>
              </div>
              <button
                v-for="row in paginatedTodayRows"
                :key="row.id"
                type="button"
                class="row"
                :disabled="!isSameUtcDay(row.created_at, new Date())"
                :aria-label="`Xoá giao dịch ${row.note || 'không có ghi chú'}, ${fmt(row.amount)}`"
                @click="requestRemove(row)"
              >
                <span class="row-note">
                  <span>{{ row.note || '—' }}</span>
                  <span class="row-meta">
                      <span class="account-badge">{{ accountLabel(row.account_type) }}</span>
                      <span v-if="row.tag" class="tag-badge">{{ row.tag }}</span>
                      <span v-if="row.entry_type === 'adjustment'" class="adjustment-badge">Điều chỉnh</span>
                      <span v-else-if="row.counts_toward_daily === false" class="daily-excluded-badge">Không tính ngày</span>
                  </span>
                </span>
                <span class="row-time">{{ fmtTime(row.created_at) }}</span>
                <span class="row-amount" :class="[row.amount < 0 ? 'neg' : 'pos', { adjustment: row.entry_type === 'adjustment' }]">
                  {{ row.amount < 0 ? '' : '+' }}{{ fmt(row.amount) }}
                </span>
              </button>
            </div>
            <nav v-if="todayRows.length > pageSize" class="pagination" aria-label="Phân trang giao dịch hôm nay">
              <span class="pagination-summary">{{ todayVisibleRange }}</span>
              <div class="pagination-controls">
                <button
                  type="button"
                  :disabled="todayPage === 1"
                  @click="todayPage -= 1"
                >
                  Trước
                </button>
                <span>Trang {{ todayPage }} / {{ todayTotalPages }}</span>
                <button
                  type="button"
                  :disabled="todayPage === todayTotalPages"
                  @click="todayPage += 1"
                >
                  Sau
                </button>
              </div>
            </nav>
          </template>

          <template v-else>
            <div v-if="!entries.length" class="empty">
              Sổ còn trống. Ghi khoản chi tiêu đầu tiên phía trên.
            </div>
            <template v-else>
              <div class="history-filters" aria-label="Lọc lịch sử giao dịch">
                <button
                  type="button"
                  :class="{ active: historyPeriod === 'day' }"
                  @click="historyPeriod = 'day'"
                >
                  Ngày
                </button>
                <button
                  type="button"
                  :class="{ active: historyPeriod === 'week' }"
                  @click="historyPeriod = 'week'"
                >
                  Tuần
                </button>
                <button
                  type="button"
                  :class="{ active: historyPeriod === 'month' }"
                  @click="historyPeriod = 'month'"
                >
                  Tháng
                </button>
              </div>
            <div class="history-search-tools">
              <label class="search-field" for="transaction-search">
                <span>Tên hoặc số tiền</span>
                <input id="transaction-search" v-model="searchQuery" type="search" placeholder="Ví dụ: ăn trưa hoặc 50.000" />
              </label>
              <div class="date-search">
                <div class="date-mode-tabs" aria-label="Kiểu lọc ngày">
                  <button type="button" :class="{ active: dateSearchMode === 'day' }" @click="dateSearchMode = 'day'; dateTo = ''">Theo ngày</button>
                  <button type="button" :class="{ active: dateSearchMode === 'range' }" @click="dateSearchMode = 'range'">Khoảng ngày</button>
                </div>
                <div class="date-inputs">
                  <label>{{ dateSearchMode === 'day' ? 'Ngày' : 'Từ ngày' }} <input v-model="dateFrom" type="date" /></label>
                  <label v-if="dateSearchMode === 'range'">Đến ngày <input v-model="dateTo" type="date" /></label>
                  <button v-if="dateFrom || dateTo" type="button" class="clear-date-btn" @click="resetDateSearch">Xoá lọc ngày</button>
                </div>
              </div>
            </div>
            <div v-if="!historyRows.length" class="empty">
              Không tìm thấy giao dịch phù hợp.
            </div>
            <template v-else>
              <div v-if="historyPeriod === 'day'" class="summary-list">
                <button v-for="summary in paginatedDailySummaries" :key="summary.key" type="button" class="day-summary-row" @click="openDetails(summary.rows, summary.label)">
                  <span class="day-summary-label">{{ summary.label }}</span>
                  <span class="day-summary-values">
                    <small class="pos">+{{ fmt(summary.income) }}</small>
                    <small class="neg">−{{ fmt(summary.expense) }}</small>
                  </span>
                  <strong :class="summary.net < 0 ? 'neg' : 'pos'">{{ summary.net < 0 ? '' : '+' }}{{ fmt(summary.net) }}</strong>
                </button>
              </div>
              <div v-else class="chart-card">
                <div class="bar-chart" :class="{ compact: historyPeriod === 'month' }">
                  <button v-for="bucket in chartBuckets" :key="bucket.key" type="button" class="bar-column" :aria-label="`Mở giao dịch ${bucket.key}`" @click="openDetails(bucket.rows, historyPeriod === 'week' ? bucket.label : `Ngày ${bucket.label} trong tháng`)" :disabled="!bucket.rows.length">
                    <span class="bar-stack">
                      <span class="bar income-bar" :style="{ height: `${bucket.income / chartMax * 100}%` }"></span>
                      <span class="bar expense-bar" :style="{ height: `${bucket.expense / chartMax * 100}%` }"></span>
                    </span>
                    <span class="bar-label">{{ bucket.label }}</span>
                  </button>
                </div>
                <p class="chart-summary">Tổng chi: <strong class="neg">−{{ fmt(chartExpenseTotal) }}</strong> · Tổng thu: <strong class="pos">+{{ fmt(chartIncomeTotal) }}</strong></p>
              </div>
              <div v-if="historyPeriod === 'day' && dailySummaries.length > pageSize" class="summary-pagination pagination">
                <span>{{ dailySummaryRange }}</span>
                <div class="pagination-controls">
                  <button type="button" :disabled="currentPage === 1" @click="currentPage -= 1">Trước</button>
                  <span>Trang {{ currentPage }} / {{ dailySummaryPages }}</span>
                  <button type="button" :disabled="currentPage === dailySummaryPages" @click="currentPage += 1">Sau</button>
                </div>
              </div>
              <div v-for="group in []" :key="group.day" class="day-group">
                <div class="day-label">
                  <span>{{ group.day }}</span>
                  <span class="rule"></span>
                </div>
                <button
                  v-for="row in group.rows"
                  :key="row.id"
                  type="button"
                  class="row"
                  :disabled="!isSameUtcDay(row.created_at, new Date())"
                  :aria-label="`Xoá giao dịch ${row.note || 'không có ghi chú'}, ${fmt(row.amount)}`"
                  @click="requestRemove(row)"
                >
                  <span class="row-note">
                    <span>{{ row.note || '—' }}</span>
                    <span class="row-meta">
                    <span class="account-badge">{{ accountLabel(row.account_type) }}</span>
                    <span v-if="row.tag" class="tag-badge">{{ row.tag }}</span>
                    <span v-if="row.entry_type === 'adjustment'" class="adjustment-badge">Điều chỉnh</span>
                    <span v-else-if="row.counts_toward_daily === false" class="daily-excluded-badge">Không tính ngày</span>
                    </span>
                  </span>
                  <span class="row-time">{{ fmtTime(row.created_at) }}</span>
                  <span class="row-amount" :class="[row.amount < 0 ? 'neg' : 'pos', { adjustment: row.entry_type === 'adjustment' }]">
                    {{ row.amount < 0 ? '' : '+' }}{{ fmt(row.amount) }}
                  </span>
                  <span class="row-balance" :class="{ masked: balancesHidden }">{{ balancesHidden ? '••••••' : fmt(row.accountBalance) }}</span>
                </button>
              </div>
              <nav v-if="false" class="pagination" aria-label="Phân trang giao dịch">
                <span class="pagination-summary">{{ visibleRange }}</span>
                <div class="pagination-controls">
                  <button
                    type="button"
                    :disabled="currentPage === 1"
                    @click="currentPage -= 1"
                  >
                    Trước
                  </button>
                  <span>Trang {{ currentPage }} / {{ totalPages }}</span>
                  <button
                    type="button"
                    :disabled="currentPage === totalPages"
                    @click="currentPage += 1"
                  >
                    Sau
                  </button>
                </div>
              </nav>
            </template>
            </template>
          </template>
        </div>
        <div v-else class="loading">Đang mở sổ…</div>
      </div>
    </div>

    <div v-if="confirmingEntry" class="dialog-backdrop" @click.self="cancelRemove">
      <section
        class="confirm-dialog"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="delete-dialog-title"
        aria-describedby="delete-dialog-description"
      >
        <h2 id="delete-dialog-title">Xoá giao dịch?</h2>
        <p id="delete-dialog-description">
          {{ confirmingEntry.note || 'Giao dịch không có ghi chú' }} ·
          {{ confirmingEntry.amount < 0 ? '' : '+' }}{{ fmt(confirmingEntry.amount) }}.
          Thao tác này không thể hoàn tác.
        </p>
        <div class="dialog-actions">
          <button type="button" class="cancel-delete-btn" @click="cancelRemove">Huỷ</button>
          <button type="button" class="confirm-delete-btn" @click="confirmRemove">Xoá</button>
        </div>
      </section>
    </div>
    <div v-if="confirmingDebt" class="dialog-backdrop" @click.self="cancelRemoveDebt">
      <section class="confirm-dialog debt-confirm-dialog" role="alertdialog" aria-modal="true">
        <h2>Thanh toán khoản nợ?</h2>
        <p>
          {{ confirmingDebt.note || 'Khoản nợ không có ghi chú' }} ·
          {{ confirmingDebt.amount < 0 ? '' : '+' }}{{ fmt(confirmingDebt.amount) }}.
          {{ confirmingDebt.debt_type === 'lent' ? 'Tiền sẽ được cộng vào Tài khoản' : 'Tiền sẽ được trừ khỏi Tài khoản' }}
          và không tính vào thu nhập ngày.
        </p>
        <div class="dialog-actions">
          <button type="button" class="cancel-delete-btn" @click="cancelRemoveDebt">Huỷ</button>
          <button type="button" class="confirm-delete-btn" @click="confirmRemoveDebt">Thanh toán</button>
        </div>
      </section>
    </div>
    <div v-if="debtDetailType" class="dialog-backdrop" @click.self="closeDebtDetails">
      <section class="confirm-dialog debt-details-dialog" role="dialog" aria-modal="true">
        <div class="debt-details-heading">
          <h2>{{ debtDetailType === 'lent' ? 'Người khác đang nợ tôi' : 'Nợ hiện tại' }}</h2>
          <button type="button" class="close-details-btn" aria-label="Đóng" @click="closeDebtDetails">×</button>
        </div>
        <p>{{ visibleDebtDetails.length ? 'Chạm vào một dòng để thanh toán khoản nợ.' : 'Chưa có khoản nào.' }}</p>
        <div v-if="visibleDebtDetails.length" class="debt-list debt-details-list">
          <button v-for="debt in visibleDebtDetails" :key="debt.id" type="button" class="debt-row" @click="requestRemoveDebt(debt)">
            <span class="debt-date">{{ new Date(debt.created_at).toLocaleDateString('vi-VN') }}</span>
            <span class="debt-note">{{ debt.note || '—' }}</span>
            <span class="debt-amount">{{ debt.amount < 0 ? '' : '+' }}{{ fmt(debt.amount) }}</span>
          </button>
        </div>
      </section>
    </div>
    <div v-if="debtModalOpen" class="dialog-backdrop" @click.self="closeDebtModal">
      <section class="confirm-dialog debt-entry-dialog" role="dialog" aria-modal="true" aria-labelledby="debt-entry-title">
        <div class="debt-details-heading">
          <h2 id="debt-entry-title">Ghi khoản nợ</h2>
          <button type="button" class="close-details-btn" aria-label="Đóng" @click="closeDebtModal">×</button>
        </div>
        <form class="debt-form debt-modal-form" @submit.prevent="submitDebt">
          <label class="debt-field-label" for="debt-amount">Số tiền</label>
          <input id="debt-amount" v-model="debtInput" class="amount-input" type="text" inputmode="numeric" placeholder="Số tiền nợ" aria-label="Số tiền nợ" autofocus />
          <label class="debt-field-label" for="debt-note">Ghi chú</label>
          <input id="debt-note" v-model="debtNote" class="note-input" type="text" placeholder="Ghi chú nợ (tuỳ chọn)" aria-label="Ghi chú nợ" />
          <div class="amount-direction" aria-label="Nhóm khoản nợ">
            <button type="button" :class="{ active: debtType === 'owed' }" @click="debtType = 'owed'">Tôi đang nợ</button>
            <button type="button" :class="{ active: debtType === 'lent' }" @click="debtType = 'lent'">Cho người khác nợ</button>
          </div>
          <div class="amount-direction" aria-label="Loại khoản nợ">
            <button type="button" :class="{ active: debtDirection === 1 }" @click="debtDirection = 1">+ Phát sinh</button>
            <button type="button" :class="{ active: debtDirection === -1 }" @click="debtDirection = -1">− Thu hồi / trả</button>
          </div>
          <p v-if="error" class="debt-modal-error">{{ error }}</p>
          <div class="dialog-actions">
            <button type="button" class="cancel-delete-btn" @click="closeDebtModal">Huỷ</button>
            <button type="submit" class="confirm-delete-btn debt-submit-btn">Ghi nợ</button>
          </div>
        </form>
      </section>
    </div>
    <div v-if="tagModalOpen" class="dialog-backdrop" @click.self="closeTagModal">
      <section class="confirm-dialog tag-dialog" role="dialog" aria-modal="true" aria-labelledby="tag-dialog-title">
        <div class="debt-details-heading">
          <h2 id="tag-dialog-title">Quản lý thẻ</h2>
          <button type="button" class="close-details-btn" aria-label="Đóng" @click="closeTagModal">×</button>
        </div>
        <form class="tag-add-form" @submit.prevent="submitTag">
          <input v-model="tagInput" class="note-input" type="text" placeholder="Tên thẻ mới" aria-label="Tên thẻ mới" />
          <button type="submit" class="save-balance-btn">Thêm</button>
        </form>
        <p v-if="error" class="debt-modal-error">{{ error }}</p>
        <div class="tag-list">
          <div v-for="tag in tags" :key="tag.id" class="tag-list-row">
            <template v-if="editingTagId === tag.id">
              <input v-model="editingTagName" class="note-input" type="text" :aria-label="`Tên thẻ ${tag.name}`" @keyup.enter="saveTag(tag)" />
              <button type="button" class="tag-action-btn" @click="saveTag(tag)">Lưu</button>
              <button type="button" class="tag-action-btn" @click="cancelTagEdit">Huỷ</button>
            </template>
            <template v-else>
              <span>{{ tag.name }}</span>
              <button type="button" class="tag-action-btn" @click="startTagEdit(tag)">Sửa</button>
              <button type="button" class="tag-action-btn tag-delete-btn" @click="removeTag(tag)">Xoá</button>
            </template>
          </div>
        </div>
      </section>
    </div>
    <div v-if="detailTitle" class="dialog-backdrop" @click.self="closeDetails">
      <section class="confirm-dialog detail-dialog" role="dialog" aria-modal="true">
        <div class="debt-details-heading">
          <h2>{{ detailTitle }}</h2>
          <button type="button" class="close-details-btn" aria-label="Đóng" @click="closeDetails">×</button>
        </div>
        <div class="detail-list">
          <button v-for="row in paginatedDetailRows" :key="row.id" type="button" class="row" @click="openEntryDetail(row)">
            <span class="row-note">{{ row.note || '—' }} <span class="row-meta"><span class="account-badge">{{ accountLabel(row.account_type) }}</span><span v-if="row.tag" class="tag-badge">{{ row.tag }}</span><span v-if="row.counts_toward_daily === false" class="daily-excluded-badge">Không tính ngày</span></span></span>
            <span class="row-time">{{ fmtTime(row.created_at) }}</span>
            <span class="row-amount" :class="row.amount < 0 ? 'neg' : 'pos'">{{ row.amount < 0 ? '' : '+' }}{{ fmt(row.amount) }}</span>
            <span class="row-balance" :class="{ masked: balancesHidden }">{{ balancesHidden ? '••••••' : fmt(row.accountBalance) }}</span>
          </button>
        </div>
        <nav v-if="detailRows.length > pageSize" class="pagination"><span>{{ detailVisibleRange }}</span><div class="pagination-controls"><button type="button" :disabled="detailPage === 1" @click="detailPage -= 1">Trước</button><span>{{ detailPage }} / {{ detailTotalPages }}</span><button type="button" :disabled="detailPage === detailTotalPages" @click="detailPage += 1">Sau</button></div></nav>
      </section>
    </div>
    <div v-if="selectedEntryDetail" class="dialog-backdrop" @click.self="closeEntryDetail">
      <section class="confirm-dialog entry-detail-dialog" role="dialog" aria-modal="true" aria-labelledby="entry-detail-title">
        <div class="debt-details-heading">
          <h2 id="entry-detail-title">Chi tiết giao dịch</h2>
          <button type="button" class="close-details-btn" aria-label="Đóng" @click="closeEntryDetail">×</button>
        </div>
        <p class="entry-detail-amount" :class="selectedEntryDetail.amount < 0 ? 'neg' : 'pos'">
          {{ selectedEntryDetail.amount < 0 ? '' : '+' }}{{ fmt(selectedEntryDetail.amount) }} ₫
        </p>
        <p class="entry-detail-note">{{ selectedEntryDetail.note || 'Không có ghi chú' }}</p>
      </section>
    </div>
  </div>
</template>

<style scoped>
.auth-loading {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
  background: var(--paper);
  color: var(--ink-faint);
  font-family: 'Inter', sans-serif;
  font-size: 14px;
}

.page {
  min-height: 100vh;
  display: flex;
  justify-content: center;
  padding: 32px 16px;
  background: var(--paper);
}

.passbook {
  width: 100%;
  max-width: 480px;
  display: flex;
  background: var(--paper-card);
  border-radius: 6px;
  box-shadow: 0 1px 2px rgba(43, 42, 40, 0.06), 0 12px 32px rgba(43, 42, 40, 0.12);
  overflow: hidden;
  border: 1px solid var(--rule);
}

.spine {
  width: 22px;
  background: var(--paper-spine);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
  padding: 28px 0;
  border-right: 1px dashed var(--rule-strong);
}
.hole {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--paper);
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.25);
}

.sheet {
  flex: 1;
  padding: 28px 24px 20px;
  min-width: 0;
}

.head {
  margin-bottom: 16px;
}
.head-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.sign-out-btn {
  flex: 0 0 auto;
  padding: 5px 12px;
  border: 1px solid var(--rule-strong);
  border-radius: 999px;
  background: var(--paper-card);
  color: var(--ink);
  cursor: pointer;
  font-family: 'Inter', sans-serif;
  font-size: 12px;
  line-height: 1.2;
}
.sign-out-btn:hover {
  background: rgba(156, 122, 60, 0.1);
  border-color: var(--brass);
}
.eyebrow {
  font-family: 'Inter', sans-serif;
  font-size: 11px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-faint);
  margin: 0 0 2px;
}
.head h1 {
  font-family: 'Newsreader', serif;
  font-weight: 600;
  font-size: 28px;
  color: var(--ink);
  margin: 0;
}
.balance-stamps {
  width: 100%;
  overflow: hidden;
  border: 1px solid var(--rule-strong);
  border-radius: 16px;
  background: rgba(236, 229, 211, 0.35);
}
.balance-total {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 10px 14px;
  color: var(--ink);
}
.balance-total.negative {
  color: var(--red);
}
.balance-total-label {
  font-family: 'Inter', sans-serif;
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--brass);
}
.balance-total-topline {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.balance-actions {
  display: flex;
  align-items: center;
  gap: 2px;
}
.balance-visibility-btn {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  margin: -7px -5px -7px 0;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: transparent;
  color: var(--brass);
  cursor: pointer;
}
.balance-visibility-btn:hover,
.balance-visibility-btn:focus-visible {
  background: rgba(156, 122, 60, 0.12);
}
.balance-visibility-btn:focus-visible {
  outline: 2px solid var(--brass);
  outline-offset: 1px;
}
.balance-visibility-btn svg {
  width: 20px;
  height: 20px;
  fill: none;
  stroke: currentColor;
  stroke-linecap: round;
  stroke-linejoin: round;
  stroke-width: 1.8;
}
.balance-total-amount {
  font-family: 'JetBrains Mono', monospace;
  font-size: 25px;
  line-height: 1;
  letter-spacing: -0.08em;
}
.balance-total-amount small,
.balance-source-amount small {
  font-size: 0.58em;
  font-weight: 500;
  letter-spacing: 0;
}
.masked {
  display: inline-block;
  color: var(--ink-faint) !important;
  letter-spacing: 0.04em;
}
.balance-total-amount { min-width: 152px; }
.balance-source-amount { min-width: 84px; }
.debt-summary strong { min-width: 104px; text-align: right; }
.balance-source-stamps {
  padding: 0 14px;
  background: rgba(251, 249, 243, 0.72);
}
.balance-source {
  position: relative;
  display: grid;
  grid-template-columns: 28px 1fr auto;
  align-items: center;
  gap: 8px;
  min-height: 42px;
}
.balance-source:not(:last-child)::after {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
  height: 1px;
  background: var(--rule);
  content: '';
}
.balance-source-icon {
  width: 28px;
  height: 28px;
  border-radius: 8px;
  background: #f4e7bf;
  display: grid;
  place-items: center;
}
.balance-source-icon::before {
  font-family: 'JetBrains Mono', monospace;
  font-size: 13px;
  font-weight: 700;
  color: var(--brass);
}
.balance-source.wallet .balance-source-icon::before {
  content: '▣';
}
.balance-source.bank .balance-source-icon::before {
  content: '⌂';
}
.balance-source.cash .balance-source-icon::before {
  content: '▤';
}
.balance-source-label {
  font-family: 'Inter', sans-serif;
  font-size: 12px;
  color: var(--ink);
}
.balance-source-amount {
  font-family: 'JetBrains Mono', monospace;
  font-size: 12px;
  color: var(--ink);
  white-space: nowrap;
}
.balance-source-amount.negative {
  color: var(--red);
}
.balance-controls {
  display: flex;
  flex-direction: column;
  margin-top: 14px;
}
.debt-card {
  margin-top: 10px;
  padding: 10px 12px;
  border: 1px solid rgba(166, 54, 44, 0.35);
  border-radius: 6px;
  color: var(--red);
  background: rgba(166, 54, 44, 0.05);
}
.debt-summary,
.debt-month {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  font-family: 'Inter', sans-serif;
  font-size: 11px;
}
.debt-total-button {
  width: 100%;
  padding: 0;
  border: 0;
  background: transparent;
  color: inherit;
  text-align: left;
  cursor: pointer;
}
.debt-total-button + .debt-total-button { margin-top: 6px; }
.debt-total-button:hover strong { text-decoration: underline; }
.debt-summary strong,
.debt-month strong,
.debt-amount {
  font-family: 'JetBrains Mono', monospace;
}
.debt-summary strong { font-size: 16px; }
.debt-month { margin-top: 5px; }
.debt-form { display: grid; grid-template-columns: 1fr 1fr auto; gap: 6px; margin-top: 9px; }
.debt-form .amount-input,
.debt-form .note-input { padding: 7px 8px; font-size: 11px; }
.amount-direction {
  display: flex;
  gap: 6px;
}
.amount-direction button {
  border: 1px solid var(--rule-strong);
  border-radius: 999px;
  padding: 5px 8px;
  background: var(--paper-card);
  color: var(--ink-faint);
  cursor: pointer;
  font-family: 'Inter', sans-serif;
  font-size: 11px;
}
.amount-direction button.active {
  border-color: var(--brass);
  background: rgba(156, 122, 60, 0.12);
  color: var(--ink);
  font-weight: 600;
}
.debt-form .amount-direction { grid-column: 1 / -1; }
.debt-form .amount-direction button:first-child.active { border-color: var(--red); background: rgba(166, 54, 44, 0.1); color: var(--red); }
.debt-form .debt-add-btn { grid-column: 1 / -1; }
.debt-add-btn { border: 0; border-radius: 4px; padding: 7px 9px; background: var(--red); color: var(--paper-card); cursor: pointer; font-family: 'Inter', sans-serif; font-size: 11px; font-weight: 600; }
.debt-open-btn { width: 100%; margin-top: 10px; }
.debt-entry-dialog { width: min(100%, 380px); }
.debt-modal-form { grid-template-columns: 1fr; gap: 8px; margin-top: 14px; }
.debt-modal-form .amount-input,
.debt-modal-form .note-input { padding: 10px 12px; font-size: 14px; }
.debt-field-label { font-family: 'Inter', sans-serif; font-size: 12px; color: var(--ink-faint); }
.debt-modal-form .amount-direction { flex-wrap: wrap; }
.debt-modal-form .dialog-actions { margin-top: 4px; }
.debt-modal-form .debt-submit-btn { border-color: var(--red); }
.debt-modal-error { margin: 0; font-family: 'Inter', sans-serif; font-size: 12px; color: var(--red); }
.debt-list { margin-top: 8px; border-top: 1px solid rgba(166, 54, 44, 0.18); }
.debt-row { display: grid; grid-template-columns: auto 1fr auto; gap: 7px; width: 100%; padding: 6px 0; border: 0; border-bottom: 1px solid rgba(166, 54, 44, 0.14); background: transparent; color: var(--ink); text-align: left; cursor: pointer; font-family: 'Inter', sans-serif; font-size: 11px; }
.debt-date { color: var(--ink-faint); }
.debt-note { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.debt-amount { color: var(--red); text-align: right; }
.debt-details-dialog { max-height: min(70vh, 520px); display: flex; flex-direction: column; }
.debt-details-heading { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.close-details-btn { width: 28px; height: 28px; border: 1px solid var(--rule-strong); border-radius: 50%; background: var(--paper-card); color: var(--ink-faint); cursor: pointer; font-size: 20px; line-height: 1; }
.debt-details-list { overflow-y: auto; }
.edit-balance-btn,
.cancel-balance-btn {
  font-family: 'Inter', sans-serif;
  font-size: 11px;
  color: var(--ink-faint);
  border: 0;
  padding: 7px 11px;
  border: 1px solid var(--rule-strong);
  border-radius: 999px;
  background: var(--paper-card);
  cursor: pointer;
}
.edit-balance-btn {
  display: grid;
  width: 26px;
  height: 26px;
  place-items: center;
  padding: 0;
  color: var(--brass);
}
.edit-balance-btn:hover,
.cancel-balance-btn:hover {
  color: var(--brass);
}
.edit-balance-btn:hover {
  background: rgba(156, 122, 60, 0.1);
}

.entry-form {
  display: grid;
  gap: 7px;
  margin-bottom: 6px;
}
.amount-row,
.note-daily-row {
  display: flex;
  align-items: center;
  gap: 7px;
  min-width: 0;
}
.amount-row .amount-input,
.note-daily-row .note-input {
  flex: 1;
}
.entry-direction {
  display: flex;
  flex: 0 0 auto;
  gap: 4px;
}
.entry-direction button,
.choice-group button {
  border: 1px solid var(--rule-strong);
  border-radius: 999px;
  padding: 5px 8px;
  background: var(--paper-card);
  color: var(--ink-faint);
  font-family: 'Inter', sans-serif;
  font-size: 11px;
  cursor: pointer;
}
.entry-direction button.active,
.choice-group button.active {
  border-color: var(--brass);
  background: rgba(156, 122, 60, 0.12);
  color: var(--ink);
  font-weight: 600;
}
.entry-direction button:first-child.active {
  border-color: var(--red);
  background: rgba(161, 45, 39, 0.1);
  color: var(--red);
}
.entry-direction button:last-child.active {
  border-color: var(--green);
  background: rgba(23, 107, 69, 0.1);
  color: var(--green);
}
.amount-row .amount-input.expense-input:focus {
  border-color: var(--red);
  color: var(--red);
}
.amount-row .amount-input.income-input:focus {
  border-color: var(--green);
  color: var(--green);
}
.choice-group {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  min-width: 0;
  margin: 0;
  padding: 0;
  border: 0;
}
.choice-group legend {
  width: 100%;
  margin-bottom: 2px;
  font-family: 'Inter', sans-serif;
  font-size: 11px;
  color: var(--ink-faint);
}
.choice-group legend span {
  font-size: 10px;
}
.choice-group .manage-tags-btn {
  margin-left: 6px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--brass);
  font: inherit;
  cursor: pointer;
}
.account-choice {
  align-items: center;
  flex-wrap: nowrap;
}
.choice-label {
  flex: 0 0 auto;
  margin-right: 2px;
  color: var(--ink-faint);
  font: 11px 'Inter', sans-serif;
}
.account-choice button,
.tag-choice button {
  padding: 4px 7px;
}
.note-daily-row {
  align-items: stretch;
}
.daily-toggle-control {
  position: relative;
  display: flex;
  flex: 0 0 auto;
  align-items: stretch;
  gap: 3px;
}
.daily-toggle {
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 0 8px;
  border: 1px solid var(--rule-strong);
  border-radius: 999px;
  color: var(--ink-faint);
  font: 10px 'Inter', sans-serif;
  cursor: pointer;
  white-space: nowrap;
}
.daily-toggle input {
  position: absolute;
  width: 1px;
  height: 1px;
  opacity: 0;
}
.toggle-track {
  position: relative;
  width: 28px;
  height: 16px;
  border-radius: 999px;
  background: var(--rule-strong);
  transition: background .2s ease;
}
.toggle-track span {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--paper-card);
  box-shadow: 0 1px 2px rgba(43, 42, 40, 0.22);
  transition: transform .2s ease;
}
.daily-toggle input:checked + .toggle-track {
  background: var(--brass);
}
.daily-toggle input:checked + .toggle-track span {
  transform: translateX(12px);
}
.daily-toggle input:focus-visible + .toggle-track {
  outline: 2px solid var(--brass);
  outline-offset: 2px;
}
.daily-info-btn {
  display: grid;
  width: 28px;
  min-height: 100%;
  place-items: center;
  padding: 0;
  border: 1px solid var(--rule-strong);
  border-radius: 50%;
  background: var(--paper-card);
  color: var(--brass);
  cursor: pointer;
  font: 700 12px/1 'Newsreader', serif;
}
.daily-info-btn:focus-visible {
  outline: 2px solid var(--brass);
  outline-offset: 2px;
}
.daily-info-tooltip {
  position: absolute;
  z-index: 2;
  top: calc(100% + 6px);
  right: 0;
  width: min(250px, calc(100vw - 48px));
  padding: 8px 10px;
  border: 1px solid var(--rule-strong);
  border-radius: 6px;
  background: var(--paper-card);
  box-shadow: 0 8px 20px rgba(43, 42, 40, 0.16);
  color: var(--ink);
  font: 11px/1.4 'Inter', sans-serif;
}
.amount-input,
.note-input {
  box-sizing: border-box;
  min-width: 0;
  width: 100%;
  font-family: 'JetBrains Mono', monospace;
  font-size: 14px;
  padding: 10px 12px;
  border: 1px solid var(--rule-strong);
  border-radius: 4px;
  background: var(--paper);
  color: var(--ink);
  outline: none;
}
.note-input {
  font-family: 'Inter', sans-serif;
}
.amount-input:focus,
.note-input:focus {
  border-color: var(--brass);
}
.add-btn {
  font-family: 'Inter', sans-serif;
  font-weight: 600;
  font-size: 13px;
  letter-spacing: 0.02em;
  padding: 8px 10px;
  border: none;
  border-radius: 4px;
  background: var(--ink);
  color: var(--paper-card);
  cursor: pointer;
}
.add-btn:hover {
  background: var(--brass);
}

.balance-form {
  display: grid;
  grid-template-columns: 1fr auto auto;
  gap: 8px;
  align-items: center;
  margin-top: 10px;
  padding: 10px;
  border: 1px solid var(--rule);
  border-radius: 4px;
  background: rgba(156, 122, 60, 0.05);
}
.balance-form label,
.balance-help {
  grid-column: 1 / -1;
  font-family: 'Inter', sans-serif;
}
.balance-form label {
  font-size: 12px;
  color: var(--ink);
}
.balance-form .amount-input {
  min-width: 0;
}
.save-balance-btn {
  font-family: 'Inter', sans-serif;
  font-size: 12px;
  font-weight: 600;
  padding: 8px 10px;
  border: 0;
  border-radius: 4px;
  background: var(--brass);
  color: var(--paper-card);
  cursor: pointer;
}
.save-balance-btn:disabled,
.cancel-balance-btn:disabled {
  cursor: default;
  opacity: 0.65;
}
.balance-help {
  margin: 0;
  font-size: 11px;
  color: var(--ink-faint);
}

.error {
  font-family: 'Inter', sans-serif;
  font-size: 12px;
  color: var(--red);
  margin: 4px 0 0;
}
.loading,
.empty {
  font-family: 'Inter', sans-serif;
  font-size: 13px;
  color: var(--ink-faint);
  text-align: center;
  padding: 24px 0;
}

.ledger {
  margin-top: 18px;
}
.view-tabs,
.history-filters {
  display: flex;
  gap: 6px;
  font-family: 'Inter', sans-serif;
}
.view-tabs {
  margin-top: 18px;
  border-bottom: 1px solid var(--rule);
}
.view-tabs button,
.history-filters button {
  border: 0;
  border-radius: 4px;
  background: transparent;
  color: var(--ink-faint);
  font-family: inherit;
  font-size: 12px;
  cursor: pointer;
}
.view-tabs button {
  margin-bottom: -1px;
  padding: 8px 10px;
  border-bottom: 2px solid transparent;
}
.view-tabs button.active {
  border-color: var(--brass);
  color: var(--ink);
  font-weight: 600;
}
.history-filters {
  margin-bottom: 12px;
}
.history-filters button {
  padding: 6px 10px;
  border: 1px solid var(--rule-strong);
  background: var(--paper-card);
}
.history-filters button.active {
  border-color: var(--brass);
  background: var(--brass);
  color: var(--paper-card);
}
.daily-balance {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 2px;
  border-bottom: 1px solid var(--rule);
  font-family: 'Inter', sans-serif;
  font-size: 12px;
  color: var(--ink-faint);
}
.daily-balance strong {
  font-family: 'JetBrains Mono', monospace;
  font-size: 17px;
  font-weight: 700;
}
.daily-balance-values {
  display: grid;
  justify-items: end;
  gap: 3px;
  text-align: right;
}
.daily-breakdown {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 5px;
  color: var(--ink-faint);
  font: 10px 'JetBrains Mono', monospace;
}
.daily-breakdown small {
  font: inherit;
  font-weight: 600;
}
.pos {
  color: var(--green);
}
.neg {
  color: var(--red);
}
.search-field {
  display: grid;
  gap: 5px;
  font-family: 'Inter', sans-serif;
  font-size: 12px;
  color: var(--ink-faint);
}
.search-field input {
  width: 100%;
  font-family: 'Inter', sans-serif;
  font-size: 13px;
  padding: 9px 10px;
  border: 1px solid var(--rule-strong);
  border-radius: 4px;
  background: var(--paper);
  color: var(--ink);
  outline: none;
}
.search-field input:focus {
  border-color: var(--brass);
}
.history-search-tools { display: grid; gap: 10px; margin-bottom: 12px; }
.date-search { display: grid; gap: 7px; }
.date-mode-tabs { display: flex; gap: 6px; }
.date-mode-tabs button, .clear-date-btn { border: 1px solid var(--rule-strong); border-radius: 4px; padding: 5px 8px; background: var(--paper-card); color: var(--ink-faint); font: 11px 'Inter', sans-serif; cursor: pointer; }
.date-mode-tabs button.active { border-color: var(--brass); color: var(--ink); background: rgba(156, 122, 60, 0.12); font-weight: 600; }
.date-inputs { display: flex; align-items: end; flex-wrap: wrap; gap: 7px; }
.date-inputs label { display: grid; gap: 3px; color: var(--ink-faint); font: 10px 'Inter', sans-serif; }
.date-inputs input { min-width: 0; padding: 7px 8px; border: 1px solid var(--rule-strong); border-radius: 4px; background: var(--paper); color: var(--ink); font: 12px 'Inter', sans-serif; }
.clear-date-btn { color: var(--red); }
.day-summary-row { display: grid; grid-template-columns: 1fr auto auto; align-items: center; gap: 10px; width: 100%; padding: 12px 2px; border: 0; border-bottom: 1px solid var(--rule); background: transparent; text-align: left; cursor: pointer; }
.day-summary-row:hover { background: rgba(156, 122, 60, 0.06); }
.day-summary-label { color: var(--ink); font: 14px 'Newsreader', serif; text-transform: capitalize; }
.day-summary-values { display: grid; gap: 2px; text-align: right; font: 10px 'JetBrains Mono', monospace; }
.day-summary-row strong { min-width: 78px; text-align: right; font: 13px 'JetBrains Mono', monospace; }
.chart-card { padding-top: 8px; }
.bar-chart { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 5px; align-items: end; min-height: 190px; padding: 12px 2px 0; border-bottom: 1px solid var(--rule-strong); }
.bar-chart.compact { grid-template-columns: repeat(auto-fit, minmax(14px, 1fr)); gap: 2px; }
.bar-column { display: flex; min-width: 0; height: 176px; flex-direction: column; align-items: center; justify-content: end; gap: 6px; border: 0; background: transparent; cursor: pointer; padding: 0; }
.bar-column:disabled { cursor: default; opacity: .45; }
.bar-stack { display: flex; width: min(20px, 80%); height: 150px; flex-direction: column; justify-content: end; gap: 1px; }
.bar { display: block; min-height: 0; border-radius: 2px 2px 0 0; transition: height .2s ease; }
.income-bar { background: var(--green); }
.expense-bar { background: var(--red); }
.bar-label { overflow: hidden; max-width: 100%; color: var(--ink-faint); font: 9px 'Inter', sans-serif; text-overflow: ellipsis; white-space: nowrap; }
.chart-summary { margin: 10px 0 0; color: var(--ink-faint); font: 11px 'Inter', sans-serif; }
.chart-summary strong { font-family: 'JetBrains Mono', monospace; }
.detail-dialog { width: min(100%, 470px); max-height: min(78vh, 620px); display: flex; flex-direction: column; }
.detail-list { overflow-y: auto; }
.detail-list .row { flex: 0 0 auto; }
.tag-dialog { width: min(100%, 400px); }
.tag-add-form { display: grid; grid-template-columns: 1fr auto; gap: 8px; margin: 14px 0; }
.tag-list { display: grid; max-height: 330px; overflow-y: auto; border-top: 1px solid var(--rule); }
.tag-list-row { display: grid; grid-template-columns: 1fr auto auto; align-items: center; gap: 7px; min-height: 42px; border-bottom: 1px solid var(--rule); color: var(--ink); font: 13px 'Inter', sans-serif; }
.tag-list-row .note-input { padding: 7px 8px; font-size: 12px; }
.tag-action-btn { border: 1px solid var(--rule-strong); border-radius: 4px; padding: 5px 7px; background: var(--paper-card); color: var(--ink-faint); font: 11px 'Inter', sans-serif; cursor: pointer; }
.tag-delete-btn { color: var(--red); }
.entry-detail-dialog { width: min(100%, 340px); }
.entry-detail-amount { margin: 18px 0 8px; font: 600 25px 'JetBrains Mono', monospace; }
.entry-detail-note { margin: 0; padding: 10px 0 4px; border-top: 1px solid var(--rule); color: var(--ink); font: 14px/1.5 'Inter', sans-serif; }
.day-group {
  margin-bottom: 4px;
}
.day-label {
  display: flex;
  align-items: center;
  gap: 8px;
  font-family: 'Inter', sans-serif;
  font-size: 11px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--ink-faint);
  margin: 14px 0 6px;
}
.day-label .rule {
  flex: 1;
  height: 1px;
  background: var(--rule);
}

.row {
  width: 100%;
  display: grid;
  grid-template-columns: 1fr auto auto auto;
  gap: 10px;
  align-items: baseline;
  padding: 7px 2px;
  border-bottom: 1px solid var(--rule);
  border-top: 0;
  border-left: 0;
  border-right: 0;
  background: transparent;
  color: inherit;
  text-align: left;
  cursor: pointer;
}
.row:hover {
  background: rgba(156, 122, 60, 0.06);
}
.row:disabled {
  cursor: default;
}
.row:disabled:hover {
  background: transparent;
}
.row-note {
  font-family: 'Inter', sans-serif;
  font-size: 13px;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.row-meta {
  display: inline-flex;
  gap: 4px;
  margin-left: 5px;
  vertical-align: middle;
}
.account-badge,
.tag-badge {
  display: inline-block;
  padding: 1px 4px;
  border: 1px solid var(--rule-strong);
  border-radius: 999px;
  color: var(--ink-faint);
  font-size: 9px;
  line-height: 1.3;
}
.tag-badge {
  border-color: rgba(156, 122, 60, 0.55);
  color: var(--brass);
}
.daily-excluded-badge { color: var(--ink-faint); font-size: 9px; }
.row-time {
  font-family: 'JetBrains Mono', monospace;
  font-size: 11px;
  color: var(--ink-faint);
  min-width: 34px;
}
.row-amount {
  font-family: 'JetBrains Mono', monospace;
  font-size: 13px;
  font-weight: 500;
  min-width: 78px;
  text-align: right;
}
.row-amount.adjustment { color: var(--ink-faint); }
.adjustment-badge { color: var(--ink-faint); font-size: 9px; }
.row-balance {
  font-family: 'JetBrains Mono', monospace;
  font-size: 12px;
  color: var(--ink-faint);
  min-width: 70px;
  text-align: right;
}

.pagination {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding-top: 16px;
  font-family: 'Inter', sans-serif;
  font-size: 11px;
  color: var(--ink-faint);
}
.pagination-controls {
  display: flex;
  align-items: center;
  gap: 6px;
  white-space: nowrap;
}
.pagination button,
.dialog-actions button {
  font-family: 'Inter', sans-serif;
  font-size: 12px;
  padding: 6px 9px;
  border: 1px solid var(--rule-strong);
  border-radius: 4px;
  background: var(--paper-card);
  color: var(--ink);
  cursor: pointer;
}
.pagination button:disabled {
  cursor: default;
  opacity: 0.5;
}

.dialog-backdrop {
  position: fixed;
  z-index: 10;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  background: rgba(43, 42, 40, 0.38);
}
.confirm-dialog {
  width: min(100%, 340px);
  padding: 20px;
  border: 1px solid var(--rule-strong);
  border-radius: 6px;
  background: var(--paper-card);
  box-shadow: 0 12px 32px rgba(43, 42, 40, 0.2);
}
.confirm-dialog h2 {
  margin: 0;
  font-family: 'Newsreader', serif;
  font-size: 22px;
}
.confirm-dialog p {
  margin: 8px 0 18px;
  font-family: 'Inter', sans-serif;
  font-size: 13px;
  line-height: 1.5;
  color: var(--ink-faint);
}
.dialog-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
.dialog-actions .confirm-delete-btn {
  border-color: var(--red);
  background: var(--red);
  color: var(--paper-card);
}

@media (max-width: 480px) {
  .page {
    padding: 12px 6px;
  }
  .spine {
    width: 18px;
  }
  .sheet {
    padding: 20px 14px 16px;
  }
  .head {
    margin-bottom: 12px;
  }
  .head h1 {
    font-size: 22px;
  }
  .entry-form {
    gap: 6px;
  }
  .amount-input,
  .note-input {
    padding: 9px 10px;
  }
  .entry-direction button {
    padding: 4px 6px;
  }
  .account-choice {
    gap: 3px;
  }
  .choice-label {
    margin-right: 0;
    font-size: 10px;
  }
  .account-choice button {
    flex: 1;
    padding-right: 5px;
    padding-left: 5px;
    font-size: 10px;
  }
  .tag-choice {
    gap: 3px;
  }
  .tag-choice button {
    padding: 3px 6px;
    font-size: 10px;
  }
  .daily-toggle {
    padding-right: 7px;
    padding-left: 7px;
  }
  .daily-info-btn {
    width: 26px;
  }
  .daily-balance {
    gap: 8px;
  }
  .daily-breakdown {
    gap: 4px;
    font-size: 9px;
  }
  .pagination {
    align-items: flex-start;
    flex-direction: column;
  }
  .row {
    gap: 6px;
  }
  .row-amount {
    min-width: 62px;
  }
  .row-balance {
    min-width: 56px;
  }
  .day-summary-row { grid-template-columns: 1fr auto; }
  .day-summary-values { grid-column: 1 / -1; grid-row: 2; display: flex; gap: 8px; text-align: left; }
}
</style>
