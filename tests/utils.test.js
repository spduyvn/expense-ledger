import test from 'node:test'
import assert from 'node:assert/strict'
import { parseMoney, parseSignedMoney } from '../src/utils/money.js'
import { addDays, dateKey, isSameDay, monthKey, weekStartKey } from '../src/utils/date.js'

test('parseMoney handles common Vietnamese amount formats', () => {
  assert.equal(parseMoney('50.000'), 50000)
  assert.equal(parseMoney('50,000'), 50000)
  assert.equal(parseMoney('1.234.567'), 1234567)
  assert.equal(parseSignedMoney('-2.500'), -2500)
  assert.equal(parseMoney('0'), null)
  assert.equal(parseMoney('29k', 'k'), 29000)
  assert.equal(parseMoney('20', 'k'), 20000)
  assert.equal(parseMoney('29k', 'vnd'), 29000)
})

test('date utilities use the requested timezone', () => {
  const value = '2026-08-15T17:30:00.000Z'
  assert.equal(dateKey(value, 'Asia/Ho_Chi_Minh'), '2026-08-16')
  assert.equal(dateKey(value, 'America/Los_Angeles'), '2026-08-15')
  assert.equal(isSameDay(value, '2026-08-16T00:01:00+07:00', 'Asia/Ho_Chi_Minh'), true)
  assert.equal(monthKey(value, 'Asia/Ho_Chi_Minh'), '2026-08')
  assert.equal(weekStartKey('2026-08-16T12:00:00+07:00', 'Asia/Ho_Chi_Minh'), '2026-08-10')
  assert.equal(addDays('2026-08-31', 1), '2026-09-01')
})
