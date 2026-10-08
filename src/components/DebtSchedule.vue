<script setup>
defineProps({
  open: Boolean,
  schedule: { type: Array, required: true },
  balancesHidden: Boolean,
  formatAmount: { type: Function, required: true }
})

defineEmits(['close'])

function monthLabel(month) {
  const [year, value] = month.split('-')
  return new Intl.DateTimeFormat('vi-VN', { month: 'long', year: 'numeric', timeZone: 'UTC' })
    .format(new Date(Date.UTC(Number(year), Number(value) - 1, 1)))
}
</script>

<template>
  <div v-if="open" class="dialog-backdrop debt-schedule-backdrop" @click.self="$emit('close')">
    <section class="confirm-dialog debt-schedule" role="dialog" aria-modal="true" aria-labelledby="debt-schedule-title">
      <div class="debt-details-heading">
        <div>
          <p class="settings-kicker">Theo dõi khoản phải trả</p>
          <h2 id="debt-schedule-title">Lịch trả nợ</h2>
        </div>
        <button type="button" class="close-details-btn" aria-label="Đóng" @click="$emit('close')">×</button>
      </div>
      <p class="debt-schedule-intro">Danh sách các khoản cần trả trong những tháng tiếp theo.</p>
      <div v-if="schedule.length" class="debt-schedule-list">
        <section v-for="month in schedule" :key="month.key" class="debt-schedule-month">
          <div class="debt-schedule-month-heading">
            <strong>{{ monthLabel(month.key) }}</strong>
            <strong :class="{ masked: balancesHidden }">{{ balancesHidden ? '••••••' : formatAmount(month.total) }} ₫</strong>
          </div>
          <div v-for="item in month.items" :key="`${month.key}-${item.debtId}`" class="debt-schedule-item">
            <span>{{ item.name }}</span>
            <strong :class="{ masked: balancesHidden }">{{ balancesHidden ? '••••••' : formatAmount(item.amount) }} ₫</strong>
          </div>
        </section>
      </div>
      <p v-else class="empty debt-empty">Chưa có lịch trả cho các tháng tiếp theo.</p>
    </section>
  </div>
</template>
