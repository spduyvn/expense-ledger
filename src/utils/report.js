export function buildMonthlyReport(rows, reportMonth, getDateKey, isCountedTowardDaily) {
  const tags = new Map()
  let income = 0
  let expense = 0

  for (const row of rows) {
    if (getDateKey(row.created_at).slice(0, 7) !== reportMonth || !isCountedTowardDaily(row)) continue
    const amount = Number(row.amount)
    if (amount > 0) income += amount
    if (amount < 0) {
      const value = Math.abs(amount)
      expense += value
      const name = row.tag || 'Không gắn thẻ'
      tags.set(name, (tags.get(name) || 0) + value)
    }
  }

  const tagExpenses = [...tags.entries()]
    .map(([name, amount]) => ({ name, amount, share: expense ? amount / expense : 0 }))
    .sort((a, b) => b.amount - a.amount || a.name.localeCompare(b.name, 'vi'))
  return { income, expense, net: income - expense, tagExpenses }
}
