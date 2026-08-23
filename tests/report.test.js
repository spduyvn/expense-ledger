import test from 'node:test'
import assert from 'node:assert/strict'
import { buildMonthlyReport } from '../src/utils/report.js'

test('buildMonthlyReport summarizes monthly cash flow and expense tags', () => {
  const rows = [
    { created_at: '2026-08-02T00:00:00Z', amount: 10000000, tag: null, entry_type: 'transaction', counts_toward_daily: true },
    { created_at: '2026-08-03T00:00:00Z', amount: -120000, tag: 'Ăn uống', entry_type: 'transaction', counts_toward_daily: true },
    { created_at: '2026-08-04T00:00:00Z', amount: -80000, tag: null, entry_type: 'transaction', counts_toward_daily: true },
    { created_at: '2026-08-05T00:00:00Z', amount: 500000, tag: null, entry_type: 'adjustment', counts_toward_daily: true },
    { created_at: '2026-07-30T00:00:00Z', amount: -90000, tag: 'Ăn uống', entry_type: 'transaction', counts_toward_daily: true }
  ]
  const report = buildMonthlyReport(rows, '2026-08', (value) => value.slice(0, 10), (entry) => entry.entry_type !== 'adjustment' && entry.counts_toward_daily !== false)
  assert.deepEqual(report, { income: 10000000, expense: 200000, net: 9800000, tagExpenses: [{ name: 'Ăn uống', amount: 120000, share: 0.6 }, { name: 'Không gắn thẻ', amount: 80000, share: 0.4 }] })
})
