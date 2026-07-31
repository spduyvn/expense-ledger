<script setup>
import { ref } from 'vue'
import { signInWithMagicLink } from '../supabase'

const email = ref('')
const sending = ref(false)
const sent = ref(false)
const error = ref('')

async function submit() {
  const normalizedEmail = email.value.trim()

  if (!/^\S+@\S+\.\S+$/.test(normalizedEmail)) {
    error.value = 'Vui lòng nhập địa chỉ email hợp lệ.'
    return
  }

  sending.value = true
  error.value = ''
  try {
    await signInWithMagicLink(normalizedEmail)
    sent.value = true
  } catch (e) {
    error.value = 'Không gửi được link đăng nhập. Vui lòng thử lại.'
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <main class="login-page">
    <section class="login-card" aria-labelledby="login-title">
      <p class="eyebrow">Sổ chi tiêu cá nhân</p>
      <h1 id="login-title">DMoney</h1>

      <template v-if="sent">
        <p class="sent-message">Kiểm tra email của bạn để đăng nhập.</p>
        <p class="sent-hint">Link đăng nhập đã được gửi đến {{ email.trim() }}.</p>
      </template>

      <form v-else @submit.prevent="submit">
        <label for="email">Email</label>
        <input
          id="email"
          v-model="email"
          type="email"
          autocomplete="email"
          placeholder="you@example.com"
          :disabled="sending"
          @input="error = ''"
        />
        <p v-if="error" class="error-message" role="alert">{{ error }}</p>
        <button type="submit" :disabled="sending">
          {{ sending ? 'Đang gửi…' : 'Gửi link đăng nhập' }}
        </button>
      </form>
    </section>
  </main>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px 16px;
  background: var(--paper);
}

.login-card {
  width: min(100%, 400px);
  padding: 32px 28px;
  background: var(--paper-card);
  border: 1px solid var(--rule);
  border-radius: 6px;
  box-shadow: 0 1px 2px rgba(43, 42, 40, 0.06), 0 12px 32px rgba(43, 42, 40, 0.12);
}

.eyebrow {
  margin: 0 0 3px;
  color: var(--ink-faint);
  font-family: 'Inter', sans-serif;
  font-size: 11px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}

h1 {
  margin: 0 0 26px;
  color: var(--ink);
  font-family: 'Newsreader', serif;
  font-size: 32px;
  font-weight: 600;
}

label {
  display: block;
  margin-bottom: 7px;
  color: var(--ink-faint);
  font-family: 'Inter', sans-serif;
  font-size: 12px;
}

input {
  width: 100%;
  padding: 11px 12px;
  border: 1px solid var(--rule-strong);
  border-radius: 4px;
  outline: none;
  background: var(--paper);
  color: var(--ink);
  font-family: 'Inter', sans-serif;
  font-size: 14px;
}

input:focus {
  border-color: var(--brass);
}

button {
  width: 100%;
  margin-top: 16px;
  padding: 11px 14px;
  border: 1px solid var(--brass);
  border-radius: 4px;
  background: var(--brass);
  color: var(--paper-card);
  cursor: pointer;
  font-family: 'Inter', sans-serif;
  font-size: 13px;
  font-weight: 600;
}

button:disabled,
input:disabled {
  cursor: not-allowed;
  opacity: 0.65;
}

.error-message {
  margin: 8px 0 0;
  color: var(--red);
  font-family: 'Inter', sans-serif;
  font-size: 12px;
}

.sent-message {
  margin: 0 0 8px;
  color: var(--green);
  font-family: 'Newsreader', serif;
  font-size: 21px;
  line-height: 1.3;
}

.sent-hint {
  margin: 0;
  color: var(--ink-faint);
  font-family: 'Inter', sans-serif;
  font-size: 13px;
  line-height: 1.5;
  overflow-wrap: anywhere;
}
</style>
