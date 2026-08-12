<script setup>
defineProps({
  currentDate: { type: String, required: true },
  isLocalEnvironment: { type: Boolean, required: true },
  balancesHidden: { type: Boolean, required: true },
  currentBalance: { type: Number, required: true },
  balancesByAccount: { type: Object, required: true },
  balanceAccountTypes: { type: Array, required: true },
  currentLent: { type: Number, required: true },
  currentDebt: { type: Number, required: true },
  formatAmount: { type: Function, required: true }
})

defineEmits(['open-settings', 'toggle-balances', 'start-balance-edit', 'open-debt-details', 'open-debt-modal'])
</script>

<template>
  <header class="head">
    <div class="head-text">
      <div class="head-meta">
        <p class="eyebrow">{{ currentDate }}</p>
        <button type="button" class="settings-btn" aria-label="Mở cài đặt" title="Cài đặt" @click="$emit('open-settings')">
          <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7ZM19.4 13.8a7.7 7.7 0 0 0 .1-1.8 7.7 7.7 0 0 0-.1-1.8l2-1.5-2-3.4-2.4 1a7.4 7.4 0 0 0-3.1-1.8L13.5 2h-4l-.4 2.5A7.4 7.4 0 0 0 6 6.3l-2.4-1-2 3.4 2 1.5a7.7 7.7 0 0 0-.1 1.8 7.7 7.7 0 0 0 .1 1.8l-2 1.5 2 3.4 2.4-1a7.4 7.4 0 0 0 3.1 1.8l.4 2.5h4l.4-2.5a7.4 7.4 0 0 0 3.1-1.8l2.4 1 2-3.4-2-1.5Z" /></svg>
          <span>Cài đặt</span>
        </button>
      </div>
      <h1>DMoney</h1>
    </div>
    <div class="balance-controls">
      <div class="balance-stamps" aria-label="Số dư theo nguồn tiền">
        <div class="balance-total" :class="{ negative: !balancesHidden && currentBalance < 0 }">
          <div class="balance-total-topline">
            <span class="balance-total-label">Tổng số dư</span>
            <div class="balance-actions">
              <button type="button" class="balance-visibility-btn" :aria-label="balancesHidden ? 'Hiện số dư' : 'Ẩn số dư'" :aria-pressed="balancesHidden" :title="balancesHidden ? 'Hiện số dư' : 'Ẩn số dư'" @click="$emit('toggle-balances')">
                <svg v-if="balancesHidden" aria-hidden="true" viewBox="0 0 24 24"><path d="M3 3l18 18M10.6 10.7a2 2 0 0 0 2.7 2.7M9.9 4.2A10.8 10.8 0 0 1 12 4c5.5 0 9 5.5 9 5.5a15.8 15.8 0 0 1-2.1 2.7M6.6 6.6A17.2 17.2 0 0 0 3 9.5S6.5 15 12 15c1 0 2-.2 2.8-.5" /></svg>
                <svg v-else aria-hidden="true" viewBox="0 0 24 24"><path d="M3 9.5S6.5 4 12 4s9 5.5 9 5.5S17.5 15 12 15 3 9.5 3 9.5Z" /><circle cx="12" cy="9.5" r="2.5" /></svg>
              </button>
              <button type="button" class="edit-balance-btn" aria-label="Điều chỉnh số dư" title="Điều chỉnh số dư" @click="$emit('start-balance-edit')"><span aria-hidden="true">✎</span></button>
            </div>
          </div>
          <strong class="balance-total-amount" :class="{ masked: balancesHidden }">{{ balancesHidden ? '••••••' : formatAmount(currentBalance) }} <small>₫</small></strong>
        </div>
        <div class="balance-source-stamps">
          <div v-for="account in balanceAccountTypes" :key="account.value" class="balance-source" :class="account.value" :aria-label="balancesHidden ? `${account.label}: số dư đang được ẩn` : `${account.label}: ${formatAmount(balancesByAccount[account.value])} đồng`">
            <span class="balance-source-icon" aria-hidden="true"></span>
            <span class="balance-source-label">{{ account.label }}</span>
            <strong class="balance-source-amount" :class="{ negative: !balancesHidden && balancesByAccount[account.value] < 0, masked: balancesHidden }">{{ balancesHidden ? '••••••' : formatAmount(balancesByAccount[account.value]) }} <small>₫</small></strong>
          </div>
        </div>
      </div>
      <section class="debt-card" aria-label="Theo dõi nợ">
        <button type="button" class="debt-summary debt-total-button" :aria-label="balancesHidden ? 'Đang cho nợ: số tiền đang được ẩn' : `Đang cho nợ: ${formatAmount(currentLent)} đồng`" @click="$emit('open-debt-details', 'lent')"><span>Đang cho nợ</span><strong :class="{ masked: balancesHidden }">{{ balancesHidden ? '••••••' : formatAmount(currentLent) }} <small>₫</small></strong></button>
        <button type="button" class="debt-summary debt-total-button" :aria-label="balancesHidden ? 'Nợ hiện tại: số tiền đang được ẩn' : `Nợ hiện tại: ${formatAmount(currentDebt)} đồng`" @click="$emit('open-debt-details', 'owed')"><span>Nợ hiện tại</span><strong :class="{ masked: balancesHidden }">{{ balancesHidden ? '••••••' : formatAmount(currentDebt) }} <small>₫</small></strong></button>
        <button type="button" class="debt-add-btn debt-open-btn" @click="$emit('open-debt-modal')">+ Ghi khoản nợ</button>
      </section>
    </div>
  </header>
</template>
