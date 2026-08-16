<script setup>
defineProps({
  open: { type: Boolean, required: true },
  isLocalEnvironment: { type: Boolean, required: true },
  appearance: { type: String, required: true },
  dayResetTimeZone: { type: String, required: true }
})

defineEmits(['close', 'update:appearance', 'update:day-reset-time-zone', 'open-tag-manager', 'sign-out'])
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
          <button type="button" class="appearance-option midnight-option" :class="{ active: appearance === 'midnight' }" role="radio" :aria-checked="appearance === 'midnight'" @click="$emit('update:appearance', 'midnight')">
            <span class="appearance-preview" aria-hidden="true"><i></i><i></i><i></i></span>
            <span><strong>Đêm neon</strong><small>Nền tối, biểu đồ rực sáng và bố cục dữ liệu tập trung.</small></span>
          </button>
          <button type="button" class="appearance-option breeze-option" :class="{ active: appearance === 'breeze' }" role="radio" :aria-checked="appearance === 'breeze'" @click="$emit('update:appearance', 'breeze')">
            <span class="appearance-preview" aria-hidden="true"><i></i><i></i><i></i></span>
            <span><strong>Thoáng</strong><small>Tông xanh dịu, giao diện sáng và tối giản.</small></span>
          </button>
        </div>
      </section>

      <section class="settings-section" aria-labelledby="day-reset-title">
        <h3 id="day-reset-title">Ngày ghi sổ</h3>
        <p>Múi giờ này xác định thời điểm reset tổng thu chi ngày, màn hình Hôm nay và các bộ lọc ngày.</p>
        <label class="time-zone-field" for="day-reset-time-zone">
          Múi giờ reset ngày
          <select id="day-reset-time-zone" :value="dayResetTimeZone" @change="$emit('update:day-reset-time-zone', $event.target.value)">
            <option value="Asia/Ho_Chi_Minh">Việt Nam (GMT+7)</option>
            <option value="Asia/Bangkok">Bangkok (GMT+7)</option>
            <option value="Asia/Singapore">Singapore (GMT+8)</option>
            <option value="Asia/Tokyo">Tokyo (GMT+9)</option>
            <option value="America/Los_Angeles">Los Angeles</option>
            <option value="America/New_York">New York</option>
            <option value="Europe/London">London</option>
          </select>
        </label>
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
