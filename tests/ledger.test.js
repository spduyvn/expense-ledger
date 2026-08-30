import test from 'node:test'
import assert from 'node:assert/strict'
import { calculateBalances, searchEntries } from '../src/utils/ledger.js'

test('calculateBalances includes adjustments and keeps account balances independent', () => {
  const rows = calculateBalances([
    { id: 'b', created_at: '2026-08-02T00:00:00Z', amount: -100000, account_type: 'cash' },
    { id: 'a', created_at: '2026-08-01T00:00:00Z', amount: 1000000, account_type: 'cash' },
    { id: 'c', created_at: '2026-08-03T00:00:00Z', amount: 500000, account_type: 'bank', entry_type: 'adjustment' }
  ])
  assert.deepEqual(rows.map((row) => row.balance), [1400000, 900000, 1000000])
  assert.equal(rows[0].accountBalance, 500000)
  assert.equal(rows[1].accountBalance, 900000)
})

test('searchEntries matches Vietnamese notes and formatted amounts', () => {
  const rows = [{ amount: -50000, note: 'Ăn trưa', tag: 'Ăn uống', account_type: 'cash' }]
  const options = { formatAmount: (value) => Math.abs(value).toLocaleString('vi-VN'), accountLabel: () => 'Tiền mặt' }
  assert.equal(searchEntries(rows, 'ăn trưa', options).length, 1)
  assert.equal(searchEntries(rows, '50.000', options).length, 1)
  assert.equal(searchEntries(rows, 'bank', options).length, 0)
})
