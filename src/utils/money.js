/** Parse a whole-number VND amount; dots/commas/spaces are thousands separators. */
export function parseMoney(value, unit = 'vnd') {
  const amount = parseSignedMoney(value, unit)
  return amount !== null && amount > 0 ? amount : null
}

export function parseSignedMoney(value, unit = 'vnd') {
  const rawValue = String(value ?? '').trim().replace(/\s/g, '')
  const hasK = /k$/i.test(rawValue)
  const raw = rawValue.replace(/k$/i, '')
  if (!raw) return null

  const normalized = raw.replace(/[.,]/g, '')
  const amount = Number(normalized) * (hasK || unit === 'k' ? 1000 : 1)
  return Number.isFinite(amount) ? amount : null
}

export function formatMoney(value, unit = 'vnd', locale = 'vi-VN') {
  const amount = Number(value) || 0
  if (unit === 'k') {
    return `${new Intl.NumberFormat(locale, { maximumFractionDigits: 2 }).format(amount / 1000)}k`
  }
  return new Intl.NumberFormat(locale).format(amount)
}
