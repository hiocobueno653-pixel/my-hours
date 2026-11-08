import { describe, expect, it } from 'vitest'
import { getMonthActivities, getRecordedActivities } from './activity'
import type { LedgerEntry, WorkDayRecord } from './types'

const records: WorkDayRecord[] = [
  { date: '2026-08-01', hours: 8.5, remark: '早班', rate: 25 },
  { date: '2026-08-05', hours: 0, remark: '休息' },
]
const entries: LedgerEntry[] = [
  {
    id: 'e1',
    date: '2026-08-01',
    type: 'expense',
    amount: 20,
    category: '餐饮',
    remark: '',
    workDate: '2026-08-01',
  },
  {
    id: 'i1',
    date: '2026-08-01',
    type: 'income',
    amount: 212.5,
    category: '工资',
    remark: '',
    workDate: '2026-08-01',
  },
  {
    id: 'e2',
    date: '2026-08-02',
    type: 'expense',
    amount: 30,
    category: '交通',
    remark: '',
    workDate: undefined,
  },
]

describe('getMonthActivities', () => {
  it('returns one activity per day of the month', () => {
    const activities = getMonthActivities('2026-08', records, entries)
    expect(activities).toHaveLength(31)
    expect(activities[0]).toMatchObject({ date: '2026-08-01', day: 1 })
  })

  it('aggregates income and expense per day, rounded to 2 decimals', () => {
    const activities = getMonthActivities('2026-08', records, entries)
    const day1 = activities.find((item) => item.date === '2026-08-01')!
    expect(day1.dayIncome).toBe(212.5)
    expect(day1.dayExpense).toBe(20)
    expect(day1.linkedCount).toBe(2)
    expect(day1.record).toEqual(records[0])
  })

  it('counts linked income entries against the work date', () => {
    const activities = getMonthActivities('2026-08', records, entries)
    const day2 = activities.find((item) => item.date === '2026-08-02')!
    expect(day2.dayExpense).toBe(30)
    expect(day2.linkedCount).toBe(0)
  })
})

describe('getRecordedActivities', () => {
  it('keeps days with a record or ledger entries, newest first', () => {
    const activities = getMonthActivities('2026-08', records, entries)
    const recorded = getRecordedActivities(activities)
    expect(recorded.map((item) => item.date)).toEqual(['2026-08-05', '2026-08-02', '2026-08-01'])
  })
})
