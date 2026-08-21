<script setup>
defineProps({
  dailyBalance: { type: Number, required: true }, dailyIncome: { type: Number, required: true }, dailyExpense: { type: Number, required: true },
  todayRows: { type: Array, required: true }, paginatedRows: { type: Array, required: true }, page: { type: Number, required: true }, totalPages: { type: Number, required: true }, visibleRange: { type: String, required: true }, pageSize: { type: Number, required: true },
  formatAmount: { type: Function, required: true }, formatTime: { type: Function, required: true }, accountLabel: { type: Function, required: true }
  , deletingEntryId: { type: String, default: null }
})
defineEmits(['update:page', 'open-entry-detail'])
</script>

<template>
  <section class="today-page">
    <div class="daily-balance"><span>Thu nhập ngày</span><span class="daily-balance-values"><strong :class="dailyBalance < 0 ? 'neg' : 'pos'">{{ dailyBalance < 0 ? '' : '+' }}{{ formatAmount(dailyBalance) }}</strong><span class="daily-breakdown"><small class="pos">Thu {{ formatAmount(dailyIncome) }}</small><span aria-hidden="true">·</span><small class="neg">Chi {{ formatAmount(dailyExpense) }}</small></span></span></div>
    <div v-if="!todayRows.length" class="empty">Hôm nay chưa có giao dịch nào.</div>
    <div v-else class="day-group">
      <div class="day-label"><span>Giao dịch hôm nay</span><span class="rule"></span></div>
      <button v-for="row in paginatedRows" :key="row.id" type="button" class="row" :disabled="deletingEntryId === row.id" :aria-label="`Xem chi tiết giao dịch, ${formatAmount(row.amount)}`" @click="$emit('open-entry-detail', row)">
        <span class="transaction-icon" :class="row.amount < 0 ? 'expense' : 'income'" aria-hidden="true">
          <svg v-if="row.amount < 0" viewBox="0 0 24 24"><path d="M7 7h10v10M17 7 7 17" /></svg>
          <svg v-else viewBox="0 0 24 24"><path d="M7 17h10V7M7 17 17 7" /></svg>
        </span>
        <span class="row-note"><span class="row-meta row-meta-only"><span class="account-badge">{{ accountLabel(row.account_type) }}</span><span v-if="row.tag" class="tag-badge">{{ row.tag }}</span><span v-if="row.entry_type === 'adjustment'" class="adjustment-badge">Điều chỉnh</span><span v-else-if="row.counts_toward_daily === false" class="daily-excluded-badge">Không tính ngày</span></span></span>
        <span class="row-time">{{ formatTime(row.created_at) }}</span><span class="row-amount" :class="[row.amount < 0 ? 'neg' : 'pos', { adjustment: row.entry_type === 'adjustment' }]">{{ row.amount < 0 ? '' : '+' }}{{ formatAmount(row.amount) }}</span>
      </button>
    </div>
    <nav v-if="todayRows.length > pageSize" class="pagination" aria-label="Phân trang giao dịch hôm nay"><span>{{ visibleRange }}</span><div class="pagination-controls"><button type="button" :disabled="page === 1" @click="$emit('update:page', page - 1)">Trước</button><span>Trang {{ page }} / {{ totalPages }}</span><button type="button" :disabled="page === totalPages" @click="$emit('update:page', page + 1)">Sau</button></div></nav>
  </section>
</template>
