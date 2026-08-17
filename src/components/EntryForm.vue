<script setup>
defineProps({
  input: { type: String, required: true },
  note: { type: String, required: true },
  selectedAccountType: { type: String, default: null },
  selectedTag: { type: String, default: null },
  entryDirection: { type: Number, required: true },
  countsTowardDaily: { type: Boolean, required: true },
  accountTypes: { type: Array, required: true },
  tags: { type: Array, required: true }, loading: { type: Boolean, default: false }
  , moneyUnit: { type: String, default: 'k' }
})

defineEmits(['update:input', 'update:note', 'update:selected-account-type', 'update:selected-tag', 'update:entry-direction', 'update:counts-toward-daily', 'submit'])
</script>

<template>
  <form class="entry-form" @submit.prevent="$emit('submit')">
    <div class="amount-row">
      <input :value="input" class="amount-input" :class="entryDirection === -1 ? 'expense-input' : 'income-input'" type="text" inputmode="decimal" placeholder="Số tiền" aria-label="Số tiền" @input="$emit('update:input', $event.target.value)" />
      <div class="entry-direction" aria-label="Loại giao dịch">
        <button type="button" :class="{ active: entryDirection === -1 }" @click="$emit('update:entry-direction', -1)">− Chi</button>
        <button type="button" :class="{ active: entryDirection === 1 }" @click="$emit('update:entry-direction', 1)">+ Thu</button>
      </div>
    </div>
    <div class="choice-group account-choice" role="group" aria-label="Nguồn tiền">
      <button v-for="account in accountTypes" :key="account.value" type="button" :class="{ active: selectedAccountType === account.value }" @click="$emit('update:selected-account-type', account.value)">{{ account.label }}</button>
    </div>
    <div class="note-daily-row">
      <input :value="note" class="note-input" type="text" placeholder="Note (tuỳ chọn)" aria-label="Ghi chú" @input="$emit('update:note', $event.target.value)" />
      <div class="daily-toggle-control">
        <label class="daily-toggle"><span class="daily-toggle-text">Tính thu nhập ngày</span><input :checked="countsTowardDaily" type="checkbox" role="switch" aria-label="Tính giao dịch vào thu nhập ngày" @change="$emit('update:counts-toward-daily', $event.target.checked)" /><span class="toggle-track" aria-hidden="true"><span></span></span></label>
      </div>
    </div>
    <fieldset class="choice-group tag-choice">
      <legend>Thẻ <span>(tuỳ chọn)</span></legend>
      <button v-for="tag in tags" :key="tag.id" type="button" :class="{ active: selectedTag === tag.name }" @click="$emit('update:selected-tag', selectedTag === tag.name ? null : tag.name)">{{ tag.name }}</button>
    </fieldset>
    <button type="submit" class="add-btn" :disabled="loading">{{ loading ? 'Đang lưu…' : 'Ghi sổ' }}</button>
  </form>
</template>
