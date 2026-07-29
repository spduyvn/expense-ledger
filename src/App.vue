<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { fetchEntries, addEntry, deleteEntry } from './supabase'

const entries = ref([])
const input = ref('')
const note = ref('')
const editingBalance = ref(false)
const balanceInput = ref('')
const savingBalance = ref(false)
const loading = ref(true)
const error = ref('')
const activeView = ref('today')
const historyPeriod = ref('month')
const searchQuery = ref('')
const currentPage = ref(1)
const confirmingEntry = ref(null)
const pageSize = 10

onMounted(load)

async function load() {
  loading.value = true
  try {
    entries.value = await fetchEntries()
  } catch (e) {
    error.value = 'Không tải được sổ. Kiểm tra kết nối Supabase.'
  } finally {
    loading.value = false
  }
}

// Số dư được tính luỹ kế trên toàn bộ sổ, từ giao dịch cũ nhất đến mới nhất.
const withBalance = computed(() => {
  const chrono = [...entries.value].sort((a, b) => {
    const timeDiff = new Date(a.created_at) - new Date(b.created_at)
    return timeDiff || a.id.localeCompare(b.id)
  })
  let running = 0
  const rows = chrono.map((e) => {
    running += e.amount
    return { ...e, balance: running }
  })
  return rows.reverse()
})

const currentBalance = computed(() => withBalance.value[0]?.balance ?? 0)
const currentDate = new Intl.DateTimeFormat('vi-VN', {
  weekday: 'long',
  day: '2-digit',
  month: '2-digit',
  year: 'numeric'
}).format(new Date())

function dateKey(value) {
  const date = new Date(value)
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function isSameLocalDay(value, date) {
  return dateKey(value) === dateKey(date)
}

function startOfDay(date = new Date()) {
  const result = new Date(date)
  result.setHours(0, 0, 0, 0)
  return result
}

function isInHistoryPeriod(value) {
  const date = new Date(value)
  const now = new Date()
  const today = startOfDay(now)

  if (historyPeriod.value === 'day') return isSameLocalDay(date, today)

  if (historyPeriod.value === 'week') {
    const weekStart = new Date(today)
    const weekday = weekStart.getDay() || 7
    weekStart.setDate(weekStart.getDate() - weekday + 1)
    return date >= weekStart && date <= now
  }

  return date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth()
}

function fmtTime(value) {
  return new Intl.DateTimeFormat('vi-VN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  }).format(new Date(value))
}

function groupByDay(rows) {
  const groups = []
  let currentDay = null
  for (const row of rows) {
    const day = new Date(row.created_at).toLocaleDateString('vi-VN', {
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
    return noteMatches || amountMatches
  })
})

const todayRows = computed(() => withBalance.value.filter((row) => isSameLocalDay(row.created_at, new Date())))
const dailyBalance = computed(() => todayRows.value.reduce((total, row) => total + Number(row.amount), 0))
const historyRows = computed(() => filteredRows.value.filter((row) => isInHistoryPeriod(row.created_at)))

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

watch(searchQuery, () => {
  currentPage.value = 1
})

watch(historyPeriod, () => {
  currentPage.value = 1
})

watch(totalPages, (pages) => {
  if (currentPage.value > pages) currentPage.value = pages
})

async function submit() {
  const raw = input.value.trim()
  if (!raw) return
  const amount = Number(raw.replace(/[, ]/g, ''))
  if (Number.isNaN(amount) || amount === 0) {
    error.value = 'Nhập số dạng -25000 hoặc +30000'
    return
  }
  error.value = ''
  try {
    const created = await addEntry(amount, note.value.trim() || null)
    entries.value = [created, ...entries.value]
    input.value = ''
    note.value = ''
    currentPage.value = 1
  } catch (e) {
    error.value = 'Không lưu được. Thử lại.'
  }
}

function startBalanceEdit() {
  balanceInput.value = String(currentBalance.value)
  editingBalance.value = true
  error.value = ''
}

function cancelBalanceEdit() {
  editingBalance.value = false
  balanceInput.value = ''
}

async function saveBalance() {
  const raw = balanceInput.value.trim()
  const targetBalance = Number(raw.replace(/[, ]/g, ''))
  if (!raw || Number.isNaN(targetBalance)) {
    error.value = 'Nhập số dư hợp lệ'
    return
  }

  const adjustment = targetBalance - currentBalance.value
  if (adjustment === 0) {
    cancelBalanceEdit()
    return
  }

  error.value = ''
  savingBalance.value = true
  try {
    const created = await addEntry(adjustment, 'Điều chỉnh số dư')
    entries.value = [created, ...entries.value]
    cancelBalanceEdit()
    currentPage.value = 1
  } catch (e) {
    error.value = 'Không cập nhật được số dư. Thử lại.'
  } finally {
    savingBalance.value = false
  }
}

function requestRemove(entry) {
  confirmingEntry.value = entry
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
</script>

<template>
  <div class="page">
    <div class="passbook">
      <div class="spine">
        <span v-for="i in 14" :key="i" class="hole"></span>
      </div>

      <div class="sheet">
        <header class="head">
          <div class="head-text">
            <p class="eyebrow">{{ currentDate }}</p>
            <h1>DMoney</h1>
          </div>
          <div class="balance-controls">
            <div class="stamp" :class="{ negative: currentBalance < 0 }">
              <span class="stamp-label">Số dư</span>
              <span class="stamp-amount">{{ fmt(currentBalance) }}</span>
            </div>
            <button type="button" class="edit-balance-btn" @click="startBalanceEdit">
              Điều chỉnh
            </button>
          </div>
        </header>

        <form class="entry-form" @submit.prevent="submit">
          <input
            v-model="input"
            class="amount-input"
            type="text"
            inputmode="numeric"
            placeholder="Vnd"
            aria-label="Số tiền"
          />
          <input
            v-model="note"
            class="note-input"
            type="text"
            placeholder="Note (tuỳ chọn)"
            aria-label="Ghi chú"
          />
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
              <span>Số dư ngày</span>
              <strong :class="dailyBalance < 0 ? 'neg' : 'pos'">
                {{ dailyBalance < 0 ? '' : '+' }}{{ fmt(dailyBalance) }}
              </strong>
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
                v-for="row in todayRows"
                :key="row.id"
                type="button"
                class="row"
                :aria-label="`Xoá giao dịch ${row.note || 'không có ghi chú'}, ${fmt(row.amount)}`"
                @click="requestRemove(row)"
              >
                <span class="row-note">{{ row.note || '—' }}</span>
                <span class="row-time">{{ fmtTime(row.created_at) }}</span>
                <span class="row-amount" :class="row.amount < 0 ? 'neg' : 'pos'">
                  {{ row.amount < 0 ? '' : '+' }}{{ fmt(row.amount) }}
                </span>
                <span class="row-balance">{{ fmt(row.balance) }}</span>
              </button>
            </div>
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
            <label class="search-field" for="transaction-search">
              <span>Tìm giao dịch</span>
              <input
                id="transaction-search"
                v-model="searchQuery"
                type="search"
                placeholder="Tên hoặc số tiền"
              />
            </label>

            <div v-if="!historyRows.length" class="empty">
              Không tìm thấy giao dịch phù hợp.
            </div>

            <template v-else>
              <div v-for="group in grouped" :key="group.day" class="day-group">
                <div class="day-label">
                  <span>{{ group.day }}</span>
                  <span class="rule"></span>
                </div>
                <button
                  v-for="row in group.rows"
                  :key="row.id"
                  type="button"
                  class="row"
                  :aria-label="`Xoá giao dịch ${row.note || 'không có ghi chú'}, ${fmt(row.amount)}`"
                  @click="requestRemove(row)"
                >
                  <span class="row-note">{{ row.note || '—' }}</span>
                  <span class="row-time">{{ fmtTime(row.created_at) }}</span>
                  <span class="row-amount" :class="row.amount < 0 ? 'neg' : 'pos'">
                    {{ row.amount < 0 ? '' : '+' }}{{ fmt(row.amount) }}
                  </span>
                  <span class="row-balance">{{ fmt(row.balance) }}</span>
                </button>
              </div>

              <nav class="pagination" aria-label="Phân trang giao dịch">
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
  </div>
</template>

<style scoped>
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
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 20px;
  gap: 12px;
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

.stamp {
  flex-shrink: 0;
  width: 92px;
  height: 92px;
  border-radius: 50%;
  border: 2px solid var(--brass);
  color: var(--brass);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  transform: rotate(-8deg);
  font-family: 'JetBrains Mono', monospace;
  text-align: center;
  line-height: 1.2;
}
.stamp.negative {
  border-color: var(--red);
  color: var(--red);
}
.stamp-label {
  font-family: 'Inter', sans-serif;
  font-size: 9px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  opacity: 0.85;
}
.stamp-amount {
  font-size: 15px;
  font-weight: 700;
  padding: 0 6px;
  word-break: break-all;
}
.balance-controls {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
}
.edit-balance-btn,
.cancel-balance-btn {
  font-family: 'Inter', sans-serif;
  font-size: 11px;
  color: var(--ink-faint);
  border: 0;
  padding: 2px 4px;
  background: transparent;
  cursor: pointer;
}
.edit-balance-btn:hover,
.cancel-balance-btn:hover {
  color: var(--brass);
}

.entry-form {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-bottom: 6px;
}
.amount-input,
.note-input {
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
  grid-column: 1 / -1;
  font-family: 'Inter', sans-serif;
  font-weight: 600;
  font-size: 13px;
  letter-spacing: 0.02em;
  padding: 10px;
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
  align-items: baseline;
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
  font-size: 16px;
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
.row-note {
  font-family: 'Inter', sans-serif;
  font-size: 13px;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
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
.row-amount.neg {
  color: var(--red);
}
.row-amount.pos {
  color: var(--green);
}
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

@media (max-width: 380px) {
  .stamp {
    width: 78px;
    height: 78px;
  }
  .head h1 {
    font-size: 22px;
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
}
</style>
