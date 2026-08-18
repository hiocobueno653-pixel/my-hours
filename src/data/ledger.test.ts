import { describe, expect, it } from 'vitest'
import {
  DEFAULT_LEDGER_CATEGORIES,
  dedupeLedgerCategories,
  dedupeLedgerEntries,
  formatMoney,
  getAvailableLedgerCategories,
  getLedgerMonthEntries,
  getLedgerMonthSummary,
  isLedgerCategoryInUse,
  isLedgerCategoryNameAvailable,
  normalizeLedgerEntry,
  parseAmountInput,
} from './ledger'

const entries = [
  {
    id: 'income-1',
    date: '2026-08-01',
    type: 'income' as const,
    amount: 8000,
    category: '工资',
    remark: '8月工资',
  },
  {
    id: 'expense-1',
    date: '2026-08-02',
    type: 'expense' as const,
    amount: 128.5,
    category: '餐饮',
    remark: '午饭',
  },
  {
    id: 'expense-2',
    date: '2026-07-30',
    type: 'expense' as const,
    amount: 50,
    category: '交通',
    remark: '上月',
  },
]

describe('ledger helpers', () => {
  it('validates amount input', () => {
    expect(parseAmountInput('128.50')).toEqual({ ok: true, amount: 128.5 })
    expect(parseAmountInput('')).toEqual({ ok: false, error: '请填写金额' })
    expect(parseAmountInput('1.999')).toEqual({
      ok: false,
      error: '金额最多两位小数',
    })
    expect(parseAmountInput('0')).toEqual({
      ok: false,
      error: '金额不能为 0 或过大',
    })
  })

  it('normalizes and deduplicates ledger entries', () => {
    expect(normalizeLedgerEntry(entries[0])).toEqual(entries[0])
    expect(normalizeLedgerEntry({ ...entries[0], amount: 'bad' })).toBeNull()
    const duplicated = dedupeLedgerEntries([entries[0], { ...entries[0], amount: 999 }])
    expect(duplicated).toHaveLength(1)
    expect(duplicated[0].amount).toBe(999)
  })

  it('filters a month and sorts newest first', () => {
    const month = getLedgerMonthEntries(entries, '2026-08')
    expect(month.map((entry) => entry.id)).toEqual(['expense-1', 'income-1'])
  })

  it('summarizes income, expense, and balance by month', () => {
    expect(getLedgerMonthSummary(entries, '2026-08')).toEqual({
      income: 8000,
      expense: 128.5,
      balance: 7871.5,
    })
    expect(formatMoney(7871.5)).toBe('7871.5')
  })

  it('supports custom categories and protects used categories', () => {
    const custom = [
      { id: 'category-1', type: 'expense' as const, name: '房租' },
    ]
    const options = getAvailableLedgerCategories('expense', custom, '临时')
    expect(options).toContain('房租')
    expect(options).toContain('临时')
    expect(getAvailableLedgerCategories('expense', custom)).toEqual([
      ...DEFAULT_LEDGER_CATEGORIES.expense,
      '房租',
    ])
    expect(isLedgerCategoryNameAvailable('expense', '餐饮', custom)).toBe(false)
    expect(isLedgerCategoryNameAvailable('expense', '房租', custom)).toBe(false)
    expect(isLedgerCategoryNameAvailable('expense', '加班餐', custom)).toBe(true)
    expect(
      dedupeLedgerCategories([
        ...custom,
        { id: 'category-2', type: 'expense', name: '房租' },
      ]),
    ).toEqual(custom)
    expect(isLedgerCategoryInUse(entries, 'expense', '餐饮')).toBe(true)
    expect(isLedgerCategoryInUse(entries, 'expense', '房租')).toBe(false)
  })
})
