export function buildMonthlyReport(rows, reportMonth, getDateKey, isCountedTowardDaily) {
  const tags = new Map()
  const incomeTags = new Map()
  const [year, month] = reportMonth.split('-').map(Number)
  const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate()
  const dailyCashflow = Array.from({ length: daysInMonth }, (_, index) => ({
    key: `${reportMonth}-${String(index + 1).padStart(2, '0')}`,
    day: index + 1,
    income: 0,
    expense: 0,
    net: 0
  }))
  const dailyByKey = new Map(dailyCashflow.map((day) => [day.key, day]))
  let income = 0
  let expense = 0

  for (const row of rows) {
    const dayKey = getDateKey(row.created_at)
    if (dayKey.slice(0, 7) !== reportMonth || !isCountedTowardDaily(row)) continue
    const amount = Number(row.amount)
    const day = dailyByKey.get(dayKey)
    if (amount > 0) {
      income += amount
      if (day) day.income += amount
      const name = row.tag || 'Không gắn thẻ'
      incomeTags.set(name, (incomeTags.get(name) || 0) + amount)
    }
    if (amount < 0) {
      const value = Math.abs(amount)
      expense += value
      if (day) day.expense += value
      const name = row.tag || 'Không gắn thẻ'
      tags.set(name, (tags.get(name) || 0) + value)
    }
  }

  for (const day of dailyCashflow) day.net = day.income - day.expense

  const tagExpenses = [...tags.entries()]
    .map(([name, amount]) => ({ name, amount, share: expense ? amount / expense : 0 }))
    .sort((a, b) => b.amount - a.amount || a.name.localeCompare(b.name, 'vi'))
  const tagIncomes = [...incomeTags.entries()]
    .map(([name, amount]) => ({ name, amount, share: income ? amount / income : 0 }))
    .sort((a, b) => b.amount - a.amount || a.name.localeCompare(b.name, 'vi'))
  return { income, expense, net: income - expense, tagExpenses, tagIncomes, dailyCashflow }
}
