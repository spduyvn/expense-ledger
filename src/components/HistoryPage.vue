<script setup>
defineProps({ entries: { type: Array, required: true }, historyPeriod: { type: String, required: true }, historyMode: { type: String, required: true }, calendarCells: { type: Array, required: true }, calendarWeekdays: { type: Array, required: true }, calendarTitle: { type: String, required: true }, calendarCanNext: { type: Boolean, required: true }, searchQuery: { type: String, required: true }, historyRows: { type: Array, required: true }, dailySummaries: { type: Array, required: true }, formatAmount: { type: Function, required: true } })
defineEmits(['update:history-period', 'update:history-mode', 'update:search-query', 'open-details', 'move-calendar'])
</script>
<template>
  <section class="history-page">
    <div v-if="!entries.length" class="empty">Sổ còn trống.</div>
    <template v-else>
      <div class="history-mode-tabs"><button type="button" :class="{ active: historyMode === 'calendar' }" @click="$emit('update:history-mode', 'calendar')">Xem dạng lịch</button><button type="button" :class="{ active: historyMode === 'list' }" @click="$emit('update:history-mode', 'list')">Xem giao dịch</button></div>
      <div class="history-filters"><button v-for="period in [['day', 'Ngày'], ['week', 'Tuần'], ['month', 'Tháng']]" :key="period[0]" type="button" :class="{ active: historyPeriod === period[0] }" @click="$emit('update:history-period', period[0])">{{ period[1] }}</button></div>
      <label class="search-field">Tên hoặc số tiền<input :value="searchQuery" type="search" placeholder="Ví dụ: ăn trưa hoặc 50.000" @input="$emit('update:search-query', $event.target.value)" /></label>
      <div v-if="historyMode === 'calendar'"><div class="calendar-toolbar"><button type="button" aria-label="Khoảng trước" @click="$emit('move-calendar', -1)">‹</button><strong>{{ calendarTitle }}</strong><button type="button" aria-label="Khoảng sau" :disabled="!calendarCanNext" @click="$emit('move-calendar', 1)">›</button></div><div v-if="historyPeriod === 'day'" class="calendar-header"><span v-for="wd in calendarWeekdays" :key="wd">{{ wd }}</span></div><div class="calendar-grid" :class="`calendar-${historyPeriod}`"><template v-if="historyPeriod === 'day'"><span v-for="n in calendarCells[0]?.firstDay || 0" :key="`empty-${n}`" class="calendar-empty"></span></template><button v-for="cell in calendarCells" :key="cell.key" type="button" class="calendar-cell" :class="{ today: cell.isToday, 'has-entries': cell.rows.length }" :disabled="!cell.rows.length" @click="$emit('open-details', cell.rows, cell.label)"><strong class="day-num">{{ cell.dayNumber || cell.label }}</strong><span v-if="cell.rows.length" class="cell-summary"><small v-if="cell.income" class="transaction-amount pos">Thu +{{ formatAmount(cell.income) }}</small><small v-if="cell.expense" class="transaction-amount neg">Chi −{{ formatAmount(cell.expense) }}</small></span></button></div></div>
      <div v-else class="summary-list"><button v-for="summary in dailySummaries" :key="summary.key" type="button" class="day-summary-row" @click="$emit('open-details', summary.rows, summary.label)"><span>{{ summary.label }}</span><strong :class="summary.net < 0 ? 'neg' : 'pos'">Net {{ summary.net < 0 ? '' : '+' }}{{ formatAmount(summary.net) }}</strong></button></div>
    </template>
  </section>
</template>

