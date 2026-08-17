<script setup>
defineProps({ toasts: { type: Array, required: true } })
defineEmits(['dismiss'])
</script>

<template>
  <div class="toast-stack" aria-live="polite" aria-atomic="true">
    <div v-for="toast in toasts" :key="toast.id" class="toast" :class="`toast-${toast.type}`" role="status">
      <span>{{ toast.message }}</span>
      <button type="button" aria-label="Đóng thông báo" @click="$emit('dismiss', toast.id)">×</button>
    </div>
  </div>
</template>
