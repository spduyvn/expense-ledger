function partsFor(value, timeZone) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).formatToParts(new Date(value))
  return Object.fromEntries(parts.filter(({ type }) => type !== 'literal').map(({ type, value: part }) => [type, part]))
}

export function dateKey(value = new Date(), timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone) {
  const parts = partsFor(value, timeZone)
  return `${parts.year}-${parts.month}-${parts.day}`
}

export function isSameDay(a, b = new Date(), timeZone) {
  return dateKey(a, timeZone) === dateKey(b, timeZone)
}

export function addDays(key, days) {
  const [year, month, day] = key.split('-').map(Number)
  const date = new Date(Date.UTC(year, month - 1, day + days))
  return date.toISOString().slice(0, 10)
}

export function monthKey(value = new Date(), timeZone) {
  return dateKey(value, timeZone).slice(0, 7)
}

export function weekStartKey(value = new Date(), timeZone) {
  const key = dateKey(value, timeZone)
  const [year, month, day] = key.split('-').map(Number)
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay() || 7
  return addDays(key, 1 - weekday)
}

export function formatDate(value, timeZone, options = {}) {
  return new Intl.DateTimeFormat('vi-VN', { ...options, timeZone }).format(new Date(value))
}

export function browserTimeZone() {
  return Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Ho_Chi_Minh'
}
