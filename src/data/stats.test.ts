import { describe, expect, it } from 'vitest'
import {
  getMonthCategoryTotals,
  getMonthWorkBreakdown,
  getYearHoursTrend,
  getYearLedgerTrend,
  getYearSummary,
} from './stats'

const records = [
  { date: '2026-08-01', hours: 8, remark: '', rate: 20 },
  { date: '2026-08-02', hours: 8.5, remark: '', rate: 25 },
  { date: '2026-09-01', hours: 6, remark: '', rate: 20 },
  { date: '2026-08-03', hours: 4, remark: '', workId: 'w2' },
]

const workProfiles = [
  { id: 'work-default', name: '默认工作', hourlyRate: 20 },
  { id: 'w2', name: '家教', hourlyRate: 0 },
]

const entries = [
  { id: 'e1', date: '2026-08-01', type: 'income' as const, amount: 5000, category: '工资', remark: '' },
  { id: 'e2', date: '2026-08-02', type: 'expense' as const, amount: 35.5, category: '餐饮', remark: '' },
  { id: 'e3', date: '2026-09-01', type: 'expense' as const, amount: 120, category: '购物', remark: '' },
]

describe('getYearHoursTrend', () => {
  it('aggregates monthly hours and pay', () => {
    const trend = getYearHoursTrend(records, 2026)
    expect(trend[7]).toEqual({ yearMonth: '2026-08', hours: 20.5, pay: 372.5, workDays: 3 })
    expect(trend[8]).toEqual({ yearMonth: '2026-09', hours: 6, pay: 120, workDays: 1 })
    expect(trend[0].hours).toBe(0)
  })
})

describe('getYearLedgerTrend', () => {
  it('aggregates monthly income and expense', () => {
    const trend = getYearLedgerTrend(entries, 2026)
    expect(trend[7]).toEqual({ yearMonth: '2026-08', income: 5000, expense: 35.5 })
    expect(trend[8]).toEqual({ yearMonth: '2026-09', income: 0, expense: 120 })
  })
})

describe('getMonthCategoryTotals', () => {
  it('groups by category sorted by total desc', () => {
    const totals = getMonthCategoryTotals(entries, '2026-08')
    expect(totals).toEqual([
      { name: '工资', type: 'income', total: 5000 },
      { name: '餐饮', type: 'expense', total: 35.5 },
    ])
  })
})

describe('getMonthWorkBreakdown', () => {
  it('groups hours and pay by work', () => {
    const rows = getMonthWorkBreakdown(records, workProfiles, '2026-08')
    expect(rows).toEqual([
      { workId: 'work-default', name: '默认工作', hours: 16.5, pay: 372.5 },
      { workId: 'w2', name: '家教', hours: 4, pay: 0 },
    ])
  })
})

describe('getYearSummary', () => {
  it('sums hours, pay, income and expense for the year', () => {
    const summary = getYearSummary(records, entries, 2026)
    expect(summary).toEqual({
      totalHours: 26.5,
      totalPay: 492.5,
      totalIncome: 5000,
      totalExpense: 155.5,
    })
  })
})
