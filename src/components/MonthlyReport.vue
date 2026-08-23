<script setup>
defineProps({
  monthLabel: { type: String, required: true },
  canMoveNext: { type: Boolean, required: true },
  report: { type: Object, required: true },
  formatAmount: { type: Function, required: true }
})
defineEmits(['move-month'])
</script>

<template>
  <section class="monthly-report" aria-label="Báo cáo tháng">
    <div class="report-heading">
      <div><p class="eyebrow">Tổng quan tài chính</p><h2>Báo cáo tháng</h2></div>
      <div class="report-month-nav"><button type="button" aria-label="Tháng trước" @click="$emit('move-month', -1)">‹</button><strong>{{ monthLabel }}</strong><button type="button" aria-label="Tháng sau" :disabled="!canMoveNext" @click="$emit('move-month', 1)">›</button></div>
    </div>
    <div class="report-metrics">
      <article class="report-metric income-metric"><span>Thu nhập</span><strong>+{{ formatAmount(report.income) }}</strong></article>
      <article class="report-metric expense-metric"><span>Chi tiêu</span><strong>−{{ formatAmount(report.expense) }}</strong></article>
      <article class="report-metric" :class="report.net < 0 ? 'expense-metric' : 'income-metric'"><span>Dòng tiền ròng</span><strong>{{ report.net < 0 ? '−' : '+' }}{{ formatAmount(Math.abs(report.net)) }}</strong></article>
    </div>
    <section class="tag-report">
      <div class="tag-report-heading"><h3>Chi tiêu theo thẻ</h3><span>{{ report.tagExpenses.length }} thẻ</span></div>
      <div v-if="report.tagExpenses.length" class="tag-report-list">
        <div v-for="tag in report.tagExpenses" :key="tag.name" class="tag-report-row"><div class="tag-report-name"><span>{{ tag.name }}</span><small>{{ Math.round(tag.share * 100) }}%</small></div><div class="tag-report-value"><div class="tag-report-track"><span :style="{ width: `${tag.share * 100}%` }"></span></div><strong>{{ formatAmount(tag.amount) }}</strong></div></div>
      </div>
      <p v-else class="empty">Chưa có khoản chi nào được tính trong tháng này.</p>
    </section>
  </section>
</template>
