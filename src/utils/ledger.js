/**
 * Tính số dư theo thứ tự thời gian từ toàn bộ lịch sử giao dịch.
 * Điều chỉnh số dư vẫn là một biến động thật của số dư luỹ kế;
 * chỉ các báo cáo thu/chi mới loại nó khỏi thống kê ngày.
 */
export function calculateBalances(entries) {
  const chronological = [...entries].sort((a, b) => {
    const timeDiff = new Date(a.created_at) - new Date(b.created_at)
    return timeDiff || String(a.id).localeCompare(String(b.id))
  })
  let running = 0
  const runningByAccount = { cash: 0, bank: 0, wallet: 0 }

  return chronological.map((entry) => {
    const amount = Number(entry.amount)
    const accountType = entry.account_type || 'cash'
    running += amount
    runningByAccount[accountType] = (runningByAccount[accountType] || 0) + amount
    return {
      ...entry,
      account_type: accountType,
      balance: running,
      accountBalance: runningByAccount[accountType]
    }
  }).reverse()
}

export function searchEntries(rows, query, { formatAmount, accountLabel }) {
  const normalizedQuery = String(query ?? '').toLocaleLowerCase('vi-VN').trim()
  if (!normalizedQuery) return rows
  const compactQuery = normalizedQuery.replace(/[.,\s]/g, '')
  const normalize = (value) => String(value ?? '').toLocaleLowerCase('vi-VN').trim()

  return rows.filter((row) => {
    const amount = Number(row.amount)
    const amountValues = [String(row.amount), String(amount), String(Math.abs(amount)), formatAmount(amount), formatAmount(Math.abs(amount))]
    return [row.note, row.tag, accountLabel(row.account_type)].some((value) => normalize(value).includes(normalizedQuery))
      || amountValues.some((value) => {
        const normalized = normalize(value)
        return normalized.includes(normalizedQuery) || normalized.replace(/[.,\s]/g, '').includes(compactQuery)
      })
  })
}

