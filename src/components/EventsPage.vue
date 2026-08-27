<script setup>
defineProps({
  events: { type: Array, required: true }, selectedEvent: { type: Object, default: null },
  eventName: { type: String, required: true }, eventStart: { type: String, required: true }, eventEnd: { type: String, required: true }, eventNote: { type: String, required: true },
  eventAmount: { type: String, required: true }, eventEntryNote: { type: String, required: true }, eventEntryDate: { type: String, required: true }, eventDirection: { type: Number, required: true }, formatAmount: { type: Function, required: true }
})
defineEmits(['update:selected-event', 'update:event-name', 'update:event-start', 'update:event-end', 'update:event-note', 'update:event-amount', 'update:event-entry-note', 'update:event-entry-date', 'update:event-direction', 'create-event', 'add-event-entry', 'delete-event'])
</script>

<template>
  <section class="events-page">
    <div class="section-heading"><div><p class="eyebrow">Kho lưu trữ</p><h2>Sự kiện</h2></div><span class="section-count">{{ events.length }} sự kiện</span></div>
    <form class="event-create-form" @submit.prevent="$emit('create-event')">
      <label class="sr-only" for="event-name">Tên sự kiện</label><input id="event-name" :value="eventName" required placeholder="Tên sự kiện (ví dụ: Du lịch)" @input="$emit('update:event-name', $event.target.value)" />
      <div class="event-dates"><label>Từ <input :value="eventStart" type="date" required @input="$emit('update:event-start', $event.target.value)" /></label><label>Đến <input :value="eventEnd" type="date" required @input="$emit('update:event-end', $event.target.value)" /></label></div>
      <label class="sr-only" for="event-note">Ghi chú sự kiện</label><input id="event-note" :value="eventNote" placeholder="Ghi chú sự kiện (tuỳ chọn)" @input="$emit('update:event-note', $event.target.value)" />
      <button class="add-btn" type="submit">Tạo sự kiện</button>
    </form>
    <div v-if="!events.length" class="empty-state compact"><span class="empty-state-icon" aria-hidden="true">◌</span><strong>Chưa có sự kiện nào</strong><p>Tạo một sự kiện để gom các khoản chi cho chuyến đi, dự án hoặc dịp đặc biệt.</p></div>
    <div v-for="event in events" :key="event.id" class="event-card" :class="{ active: selectedEvent?.id === event.id }">
      <button class="event-card-header" type="button" @click="$emit('update:selected-event', selectedEvent?.id === event.id ? null : event)"><span><strong>{{ event.name }}</strong><small>{{ event.start_date }} — {{ event.end_date }}</small></span><span>›</span></button>
      <p v-if="event.note" class="event-note">{{ event.note }}</p>
      <div v-if="selectedEvent?.id === event.id" class="event-detail">
        <form class="event-entry-form" @submit.prevent="$emit('add-event-entry')"><div class="entry-direction"><button type="button" :class="{ active: eventDirection === -1 }" @click="$emit('update:event-direction', -1)">− Chi</button><button type="button" :class="{ active: eventDirection === 1 }" @click="$emit('update:event-direction', 1)">+ Thu</button></div><input :value="eventAmount" required placeholder="Số tiền" inputmode="decimal" @input="$emit('update:event-amount', $event.target.value)" /><input :value="eventEntryNote" placeholder="Note giao dịch" @input="$emit('update:event-entry-note', $event.target.value)" /><input :value="eventEntryDate" type="date" required @input="$emit('update:event-entry-date', $event.target.value)" /><button class="save-balance-btn" type="submit">Ghi giao dịch</button></form>
        <div v-if="event.entries?.length" class="event-entries"><div v-for="entry in event.entries" :key="entry.id"><span>{{ entry.created_at.slice(0, 10) }} · {{ entry.note || 'Không có note' }}</span><strong :class="entry.amount < 0 ? 'neg' : 'pos'">{{ entry.amount < 0 ? '' : '+' }}{{ formatAmount(entry.amount) }}</strong></div></div><p v-else class="empty">Sự kiện chưa có giao dịch.</p>
        <button class="text-danger" type="button" @click="$emit('delete-event', event)">Xoá sự kiện</button>
      </div>
    </div>
  </section>
</template>
