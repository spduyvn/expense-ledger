<script setup>
import { computed, ref, watch } from 'vue'

const props = defineProps({
  open: { type: Boolean, required: true },
  debts: { type: Array, required: true },
  balancesHidden: { type: Boolean, required: true },
  formatAmount: { type: Function, required: true },
  error: { type: String, required: true }
})
const emit = defineEmits(['close', 'create', 'increase', 'pay'])

const mode = ref('list')
const selectedId = ref(null)
const name = ref('')
const amount = ref('')
const note = ref('')
const planMonth = ref(currentMonth())
const planAmount = ref('')
const paymentAccount = ref('bank')
const plans = ref([])

const selectedDebt = computed(() => props.debts.find((debt) => debt.id === selectedId.value) || null)

watch(() => props.open, (open) => {
  if (open) resetForm()
})

function currentMonth() {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
}

function parseAmount(value) {
  const amount = Math.abs(Number(String(value).trim().replace(/[, ]/g, '')))
  return Number.isFinite(amount) && amount > 0 ? amount : null
}

function resetForm() {
  mode.value = 'list'
  selectedId.value = null
  name.value = ''
  amount.value = ''
  note.value = ''
  planMonth.value = currentMonth()
  planAmount.value = ''
  paymentAccount.value = 'bank'
  plans.value = []
}

function addPlan() {
  const value = parseAmount(planAmount.value)
  if (!value || !planMonth.value) return
  const existing = plans.value.find((plan) => plan.month === planMonth.value)
  if (existing) existing.amount += value
  else plans.value.push({ month: planMonth.value, amount: value })
  plans.value.sort((a, b) => a.month.localeCompare(b.month))
  planAmount.value = ''
}

function openDebt(debt) {
  selectedId.value = debt.id
  mode.value = 'detail'
}

function submitCreate() {
  const openingAmount = parseAmount(amount.value)
  if (!name.value.trim() || !openingAmount) return
  emit('create', { name: name.value.trim(), note: note.value.trim() || null, amount: openingAmount, plans: [...plans.value] })
}

function submitIncrease() {
  const value = parseAmount(amount.value)
  if (!selectedDebt.value || !value) return
  emit('increase', { debtId: selectedDebt.value.id, amount: value, note: note.value.trim() || null, plans: [...plans.value] })
}

function submitPayment() {
  const value = parseAmount(amount.value)
  if (!selectedDebt.value || !value || value > selectedDebt.value.balance) return
  emit('pay', { debtId: selectedDebt.value.id, amount: value, accountType: paymentAccount.value, note: note.value.trim() || null })
}
</script>

<template>
  <div v-if="open" class="dialog-backdrop debt-manager-backdrop" @click.self="$emit('close')">
    <section class="confirm-dialog debt-manager" role="dialog" aria-modal="true" aria-labelledby="debt-manager-title">
      <div class="debt-details-heading">
        <div><p class="settings-kicker">Theo dõi nghĩa vụ</p><h2 id="debt-manager-title">{{ mode === 'list' ? 'Các khoản nợ' : mode === 'create' ? 'Thêm khoản nợ' : selectedDebt?.name }}</h2></div>
        <button type="button" class="close-details-btn" aria-label="Đóng" @click="$emit('close')">×</button>
      </div>

      <template v-if="mode === 'list'">
        <p>Chọn một khoản để xem lịch trả, phát sinh thêm hoặc thanh toán.</p>
        <div v-if="debts.length" class="debt-account-list">
          <button v-for="debt in debts" :key="debt.id" type="button" class="debt-account-row" @click="openDebt(debt)">
            <span><strong>{{ debt.name }}</strong><small>Tháng này còn {{ formatAmount(debt.monthRemaining) }} ₫</small></span>
            <strong :class="{ masked: balancesHidden }">{{ balancesHidden ? '••••••' : formatAmount(debt.balance) }} ₫</strong>
          </button>
        </div>
        <p v-else class="empty debt-empty">Chưa có khoản nợ nào.</p>
        <button type="button" class="debt-add-btn debt-primary-btn" @click="mode = 'create'">+ Thêm khoản nợ</button>
      </template>

      <form v-else-if="mode === 'create' || mode === 'increase'" class="debt-modal-form" @submit.prevent="mode === 'create' ? submitCreate() : submitIncrease()">
        <label v-if="mode === 'create'" class="debt-field-label">Tên khoản nợ<input v-model="name" class="note-input" type="text" placeholder="Ví dụ: Thẻ tín dụng" autofocus></label>
        <label class="debt-field-label">{{ mode === 'create' ? 'Dư nợ ban đầu' : 'Phát sinh thêm' }}<input v-model="amount" class="amount-input" type="text" inputmode="numeric" placeholder="Số tiền"></label>
        <label class="debt-field-label">Ghi chú<input v-model="note" class="note-input" type="text" placeholder="Tuỳ chọn"></label>
        <div class="debt-plan-box"><strong>Phân bổ lịch trả <small>(tuỳ chọn)</small></strong><div class="debt-plan-add"><input v-model="planMonth" type="month"><input v-model="planAmount" class="amount-input" type="text" inputmode="numeric" placeholder="Số tiền"><button type="button" @click="addPlan">Thêm</button></div><div v-if="plans.length" class="debt-plan-list"><span v-for="plan in plans" :key="plan.month">{{ plan.month.slice(5, 7) }}/{{ plan.month.slice(0, 4) }} · {{ formatAmount(plan.amount) }} ₫ <button type="button" aria-label="Xoá kế hoạch" @click="plans = plans.filter((item) => item !== plan)">×</button></span></div></div>
        <p v-if="error" class="debt-modal-error">{{ error }}</p>
        <div class="dialog-actions"><button type="button" class="cancel-delete-btn" @click="mode = mode === 'create' ? 'list' : 'detail'">Huỷ</button><button type="submit" class="confirm-delete-btn">{{ mode === 'create' ? 'Tạo khoản nợ' : 'Ghi phát sinh' }}</button></div>
      </form>

      <template v-else-if="mode === 'detail' && selectedDebt">
        <div class="debt-detail-total"><span>Tổng nợ còn lại</span><strong :class="{ masked: balancesHidden }">{{ balancesHidden ? '••••••' : formatAmount(selectedDebt.balance) }} ₫</strong></div>
        <div class="debt-month-status"><span>Kế hoạch tháng này <strong>{{ formatAmount(selectedDebt.monthPlanned) }} ₫</strong></span><span>Đã trả <strong>{{ formatAmount(selectedDebt.monthPaid) }} ₫</strong></span><span>Còn trả <strong>{{ formatAmount(selectedDebt.monthRemaining) }} ₫</strong></span></div>
        <div class="debt-detail-actions"><button type="button" @click="amount = ''; note = ''; plans = []; mode = 'increase'">+ Phát sinh</button><button type="button" @click="amount = ''; note = ''; mode = 'pay'">Thanh toán</button></div>
        <h3>Lịch trả</h3><div class="debt-plan-history"><p v-if="!selectedDebt.plans.length">Chưa có kế hoạch trả.</p><div v-for="plan in selectedDebt.plans" :key="plan.month"><span>{{ plan.month.slice(5, 7) }}/{{ plan.month.slice(0, 4) }}</span><span>{{ formatAmount(plan.amount) }} ₫</span></div></div>
        <h3>Phát sinh gần đây</h3><div class="debt-entry-history"><div v-for="entry in selectedDebt.entries.slice(0, 6)" :key="entry.id"><span>{{ entry.note || (entry.amount < 0 ? 'Thanh toán' : 'Phát sinh') }}</span><strong :class="entry.amount < 0 ? 'pos' : 'neg'">{{ entry.amount < 0 ? '−' : '+' }}{{ formatAmount(Math.abs(entry.amount)) }} ₫</strong></div></div>
        <button type="button" class="debt-back-btn" @click="mode = 'list'">← Danh sách khoản nợ</button>
      </template>

      <form v-else-if="mode === 'pay' && selectedDebt" class="debt-modal-form" @submit.prevent="submitPayment">
        <p>Thanh toán cho <strong>{{ selectedDebt?.name }}</strong>. Số tiền sẽ trừ khỏi số dư và tổng nợ cùng lúc.</p>
        <label class="debt-field-label">Số tiền trả (tối đa {{ formatAmount(selectedDebt?.balance || 0) }} ₫)<input v-model="amount" class="amount-input" type="text" inputmode="numeric" autofocus></label>
        <label class="debt-field-label">Trừ từ nguồn tiền<select v-model="paymentAccount" class="note-input"><option value="bank">Tài khoản</option><option value="wallet">Ví</option><option value="cash">Tiền mặt</option></select></label>
        <label class="debt-field-label">Ghi chú<input v-model="note" class="note-input" type="text" placeholder="Tuỳ chọn"></label>
        <p v-if="error" class="debt-modal-error">{{ error }}</p>
        <div class="dialog-actions"><button type="button" class="cancel-delete-btn" @click="mode = 'detail'">Huỷ</button><button type="submit" class="confirm-delete-btn">Xác nhận trả nợ</button></div>
      </form>
    </section>
  </div>
</template>
