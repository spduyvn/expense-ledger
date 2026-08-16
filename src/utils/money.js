/** Parse a whole-number VND amount; dots/commas/spaces are thousands separators. */
export function parseMoney(value) {
  const amount = parseSignedMoney(value)
  return amount !== null && amount > 0 ? amount : null
}

export function parseSignedMoney(value) {
  const raw = String(value ?? '').trim().replace(/\s/g, '')
  if (!raw) return null

  const normalized = raw.replace(/[.,]/g, '')
  const amount = Number(normalized)
  return Number.isFinite(amount) ? amount : null
}

export function formatMoney(value, locale = 'vi-VN') {
  return new Intl.NumberFormat(locale).format(Number(value) || 0)
}
