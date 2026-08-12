<script setup>
defineProps({
  open: { type: Boolean, required: true },
  isLocalEnvironment: { type: Boolean, required: true },
  appearance: { type: String, required: true }
})

defineEmits(['close', 'update:appearance', 'open-tag-manager', 'sign-out'])
</script>

<template>
  <div v-if="open" class="dialog-backdrop" @click.self="$emit('close')">
    <section class="confirm-dialog settings-dialog" role="dialog" aria-modal="true" aria-labelledby="settings-title">
      <div class="debt-details-heading">
        <div>
          <p class="settings-kicker">DMoney</p>
          <h2 id="settings-title">Cài đặt</h2>
        </div>
        <button type="button" class="close-details-btn" aria-label="Đóng" @click="$emit('close')">×</button>
      </div>

      <section class="settings-section" aria-labelledby="appearance-title">
        <h3 id="appearance-title">Giao diện</h3>
        <p>Chọn cách hiển thị phù hợp với bạn.</p>
        <div class="appearance-options" role="radiogroup" aria-label="Chọn giao diện">
          <button type="button" class="appearance-option ledger-option" :class="{ active: appearance === 'ledger' }" role="radio" :aria-checked="appearance === 'ledger'" @click="$emit('update:appearance', 'ledger')">
            <span class="appearance-preview" aria-hidden="true"><i></i><i></i><i></i></span>
            <span><strong>Sổ tay</strong><small>Nền giấy, màu mực và phong cách hiện tại.</small></span>
          </button>
          <button type="button" class="appearance-option modern-option" :class="{ active: appearance === 'modern' }" role="radio" :aria-checked="appearance === 'modern'" @click="$emit('update:appearance', 'modern')">
            <span class="appearance-preview" aria-hidden="true"><i></i><i></i><i></i></span>
            <span><strong>Hiện đại</strong><small>Dashboard sáng, thẻ nổi và điểm nhấn tím.</small></span>
          </button>
        </div>
      </section>

      <section class="settings-section" aria-labelledby="tags-settings-title">
        <h3 id="tags-settings-title">Thẻ giao dịch</h3>
        <p>Thêm, sửa hoặc xoá các thẻ dùng khi ghi sổ.</p>
        <button type="button" class="manage-tags-settings-btn" @click="$emit('open-tag-manager')">Quản lý thẻ</button>
      </section>

      <section v-if="!isLocalEnvironment" class="settings-section settings-danger">
        <h3>Tài khoản</h3>
        <p>Đăng xuất khỏi thiết bị này.</p>
        <button type="button" class="sign-out-settings-btn" @click="$emit('sign-out')">Đăng xuất</button>
      </section>
    </section>
  </div>
</template>
