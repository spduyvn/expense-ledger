<script setup>
import { computed } from 'vue'

const props = defineProps({
  monthLabel: { type: String, required: true },
  canMoveNext: { type: Boolean, required: true },
  report: { type: Object, required: true },
  formatAmount: { type: Function, required: true }
})
defineEmits(['move-month'])

const cashflowMax = computed(() => Math.max(1, ...props.report.dailyCashflow.flatMap((day) => [day.income, day.expense])))
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
    <section class="cashflow-chart" aria-labelledby="cashflow-title">
      <div class="cashflow-chart-heading"><div><h3 id="cashflow-title">Dòng tiền theo ngày</h3><p>So sánh thu nhập và chi tiêu trong tháng.</p></div><div class="chart-legend" aria-label="Chú thích biểu đồ"><span><i class="legend-dot income-dot" aria-hidden="true"></i>Thu</span><span><i class="legend-dot expense-dot" aria-hidden="true"></i>Chi</span></div></div>
      <div class="cashflow-scroll" tabindex="0" aria-label="Biểu đồ cột thu chi theo ngày">
        <div class="cashflow-plot" :style="{ '--chart-max': cashflowMax }">
          <button v-for="day in report.dailyCashflow" :key="day.key" type="button" class="cashflow-day" :aria-label="`Ngày ${day.day}: thu ${formatAmount(day.income)}, chi ${formatAmount(day.expense)}, dòng tiền ròng ${day.net < 0 ? 'âm' : 'dương'} ${formatAmount(Math.abs(day.net))}`">
            <span class="cashflow-bars" aria-hidden="true"><i class="cashflow-bar income-bar" :style="{ height: `${(day.income / cashflowMax) * 100}%` }"></i><i class="cashflow-bar expense-bar" :style="{ height: `${(day.expense / cashflowMax) * 100}%` }"></i></span>
            <span class="cashflow-label">{{ day.day }}</span>
            <span class="cashflow-tooltip" role="tooltip"><strong>Ngày {{ day.day }}</strong><span>Thu <b>+{{ formatAmount(day.income) }}</b></span><span>Chi <b>−{{ formatAmount(day.expense) }}</b></span><span>Dòng tiền <b :class="day.net < 0 ? 'neg' : 'pos'">{{ day.net < 0 ? '−' : '+' }}{{ formatAmount(Math.abs(day.net)) }}</b></span></span>
          </button>
        </div>
      </div>
      <details class="cashflow-table"><summary>Xem bảng số liệu</summary><div class="cashflow-table-scroll"><table><caption class="sr-only">Dòng tiền theo từng ngày của {{ monthLabel }}</caption><thead><tr><th scope="col">Ngày</th><th scope="col">Thu</th><th scope="col">Chi</th><th scope="col">Dòng tiền</th></tr></thead><tbody><tr v-for="day in report.dailyCashflow" :key="day.key"><th scope="row">{{ day.day }}</th><td>+{{ formatAmount(day.income) }}</td><td>−{{ formatAmount(day.expense) }}</td><td :class="day.net < 0 ? 'neg' : 'pos'">{{ day.net < 0 ? '−' : '+' }}{{ formatAmount(Math.abs(day.net)) }}</td></tr></tbody></table></div></details>
    </section>
    <section class="tag-report">
      <div class="tag-report-heading"><h3>Chi tiêu theo thẻ</h3><span>{{ report.tagExpenses.length }} thẻ</span></div>
      <div v-if="report.tagExpenses.length" class="tag-report-list">
        <div v-for="tag in report.tagExpenses" :key="tag.name" class="tag-report-row"><div class="tag-report-name"><span>{{ tag.name }}</span><small>{{ Math.round(tag.share * 100) }}%</small></div><div class="tag-report-value"><div class="tag-report-track"><span :style="{ width: `${tag.share * 100}%` }"></span></div><strong>{{ formatAmount(tag.amount) }}</strong></div></div>
      </div>
      <p v-else class="empty">Chưa có khoản chi nào được tính trong tháng này.</p>
    </section>
    <section class="tag-report">
      <div class="tag-report-heading"><h3>Thu nhập theo thẻ</h3><span>{{ report.tagIncomes.length }} thẻ</span></div>
      <div v-if="report.tagIncomes.length" class="tag-report-list">
        <div v-for="tag in report.tagIncomes" :key="tag.name" class="tag-report-row"><div class="tag-report-name"><span>{{ tag.name }}</span><small>{{ Math.round(tag.share * 100) }}%</small></div><div class="tag-report-value"><div class="tag-report-track income-track"><span :style="{ width: `${tag.share * 100}%` }"></span></div><strong>{{ formatAmount(tag.amount) }}</strong></div></div>
      </div>
      <p v-else class="empty">Chưa có khoản thu nào được tính trong tháng này.</p>
    </section>
  </section>
</template>
