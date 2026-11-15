import { describe, expect, it } from 'vitest'
import type { LedgerEntry, WorkProfile } from './types'
import {
  formatHours,
  getEffectiveRate,
  getMonthSummary,
  getMonthPay,
  getRecordPay,
  normalizeRecord,
  parseHoursInput,
  roundMoney,
  toScaledCents,
} from './records'
import { isWageEntryForDate, syncWageEntries } from './wageEntries'

const profiles: WorkProfile[] = [
  { id: 'work-default', name: '默认工作', hourlyRate: 20 },
  { id: 'work-b', name: '兼职', hourlyRate: 35 },
]

describe('record validation and summaries', () => {
  it('accepts decimal hours and rejects invalid values', () => {
    expect(parseHoursInput('8.5')).toEqual({ ok: true, hours: 8.5 })
    expect(parseHoursInput('0')).toEqual({ ok: true, hours: 0 })
    expect(parseHoursInput('')).toEqual({ ok: false, error: '请填写工时' })
    expect(parseHoursInput('8.333')).toEqual({
      ok: false,
      error: '工时最多两位小数',
    })
    expect(parseHoursInput('25')).toEqual({
      ok: false,
      error: '工时需在 0 到 24 之间',
    })
  })

  it('normalizes imported records', () => {
    expect(normalizeRecord({ date: '2026-08-01', hours: 8.25, remark: '上午' })).toEqual({
      date: '2026-08-01',
      hours: 8.25,
      remark: '上午',
    })
    expect(normalizeRecord({ date: '2026-08-01', hours: 99 })).toBeNull()
    expect(normalizeRecord({ date: 'bad', hours: 8 })).toBeNull()
  })

  it('calculates month totals, work days, and averages', () => {
    const records = [
      { date: '2026-08-01', hours: 8, remark: '' },
      { date: '2026-08-02', hours: 8.5, remark: '加班' },
      { date: '2026-08-03', hours: 0, remark: '休息' },
      { date: '2026-07-31', hours: 4, remark: '上月' },
    ]
    expect(getMonthSummary(records, '2026-08')).toEqual({
      totalHours: 16.5,
      workDays: 2,
      averageHours: 8.25,
    })
    expect(formatHours(8)).toBe('8')
    expect(formatHours(8.5)).toBe('8.5')
  })
})

describe('effective rate and record pay', () => {
  it('prefers the record rate snapshot when it is positive', () => {
    expect(getEffectiveRate({ rate: 25, workId: 'work-b' }, profiles)).toBe(25)
    expect(getRecordPay({ date: '2026-08-01', hours: 8, remark: '', rate: 25 }, profiles)).toBe(200)
  })

  it('falls back to the current work rate when snapshot is 0 or missing', () => {
    expect(getEffectiveRate({ rate: 0, workId: 'work-default' }, profiles)).toBe(20)
    expect(getEffectiveRate({ workId: 'work-b' }, profiles)).toBe(35)
    // 无 workId 时按默认工作回退
    expect(getEffectiveRate({}, profiles)).toBe(20)
    expect(getRecordPay({ date: '2026-08-02', hours: 6.5, remark: '' }, profiles)).toBe(130)
  })

  it('returns 0 when no rate is available anywhere', () => {
    expect(getEffectiveRate({}, [])).toBe(0)
    expect(getEffectiveRate({ rate: 0, workId: 'work-missing' }, profiles)).toBe(0)
    expect(getRecordPay({ date: '2026-08-03', hours: 8, remark: '' }, [])).toBe(0)
  })

  it('prefers fixed daily pay and falls back to hourly calculation', () => {
    const fixed = { date: '2026-08-05', hours: 8, remark: '', fixedPay: 350 }
    expect(getRecordPay(fixed, profiles)).toBe(350)
    expect(getRecordPay({ date: '2026-08-05', hours: 8, remark: '', fixedPay: 0 }, profiles)).toBe(160)
  })
})

describe('money rounding', () => {
  it('rounds exact half values away from zero', () => {
    expect(roundMoney(1.005)).toBe(1.01)
    expect(roundMoney(-1.005)).toBe(-1.01)
    expect(roundMoney(2.675)).toBe(2.68)
    expect(roundMoney(-2.675)).toBe(-2.68)
  })

  it('calculates record pay and aggregates in integer cents', () => {
    expect(
      getRecordPay({ date: '2026-08-01', hours: 1.5, remark: '', rate: 10.25 }),
    ).toBe(15.38)
    const records = Array.from({ length: 1000 }, () => ({
      date: '2026-08-01',
      hours: 0.25,
      remark: '',
      rate: 33.33,
    }))
    const summedCents = records.reduce(
      (sum, record) => sum + toScaledCents(getRecordPay(record)),
      0,
    )
    expect(getMonthPay(records, '2026-08')).toBe(summedCents / 100)
    expect(getMonthPay(records, '2026-08')).toBe(8330)
  })
})

describe('syncWageEntries', () => {
  const settledNoSnapshot = {
    date: '2026-08-15',
    hours: 8,
    remark: '',
    settled: true as const,
  }
  const settledWithSnapshot = {
    date: '2026-08-16',
    hours: 4,
    remark: '',
    rate: 30,
    settled: true as const,
  }

  it('creates missing wage income entries for settled records', () => {
    const result = syncWageEntries(
      [settledNoSnapshot, settledWithSnapshot],
      [],
      profiles,
    )
    expect(result).toHaveLength(2)
    // 无快照 → 按默认工作时薪 20 × 8h
    expect(result[0]).toMatchObject({
      id: 'wage-2026-08-15',
      type: 'income',
      amount: 160,
      category: '工资',
    })
    // 有快照 → 30 × 4h
    expect(result[1]).toMatchObject({ id: 'wage-2026-08-16', amount: 120 })
  })

  it('keeps existing wage entries untouched (user edits preserved)', () => {
    const existing: LedgerEntry[] = [
      {
        id: 'wage-2026-08-15',
        date: '2026-08-15',
        type: 'income',
        amount: 999,
        category: '工资',
        remark: '手改过',
      },
    ]
    const result = syncWageEntries([settledNoSnapshot], existing, profiles)
    expect(result).toHaveLength(1)
    expect(result[0].amount).toBe(999)
  })

  it('returns the original array reference when nothing needs syncing', () => {
    const existing: LedgerEntry[] = [
      {
        id: 'wage-2026-08-15',
        date: '2026-08-15',
        type: 'income',
        amount: 999,
        category: '工资',
        remark: '手改过',
      },
      {
        id: 'entry-plain',
        date: '2026-08-15',
        type: 'expense',
        amount: 20,
        category: '餐饮',
        remark: '',
      },
    ]
    const result = syncWageEntries([settledNoSnapshot], existing, profiles)
    // 启动对账靠引用相等跳过无变化时的全量回写与备份轮转
    expect(result).toBe(existing)
  })

  it('replaces legacy linked income with the wage entry (no double count)', () => {
    const legacy: LedgerEntry[] = [
      {
        id: 'entry-old-1',
        date: '2026-08-15',
        type: 'income',
        amount: 400,
        category: '工资',
        remark: '结算工资',
        workDate: '2026-08-15',
      },
    ]
    const result = syncWageEntries(
      [{ ...settledNoSnapshot, rate: 50 }],
      legacy,
      profiles,
    )
    expect(result).toHaveLength(1)
    expect(isWageEntryForDate(result[0], '2026-08-15')).toBe(true)
    expect(result[0].amount).toBe(400)
  })

  it('keeps legacy income for unsettled days', () => {
    const legacy: LedgerEntry[] = [
      {
        id: 'entry-old-2',
        date: '2026-08-17',
        type: 'income',
        amount: 100,
        category: '工资',
        remark: '结算工资',
        workDate: '2026-08-17',
      },
    ]
    const result = syncWageEntries(
      [{ date: '2026-08-17', hours: 8, remark: '' }],
      legacy,
      profiles,
    )
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe('entry-old-2')
  })

  it('skips unsettled records and removes stale wage entries', () => {
    const unsettled = { date: '2026-08-17', hours: 8, remark: '' }
    const stale: LedgerEntry[] = [
      {
        id: 'wage-2026-08-17',
        date: '2026-08-17',
        type: 'income',
        amount: 160,
        category: '工资',
        remark: '结算工资',
        workDate: '2026-08-17',
      },
    ]
    const result = syncWageEntries([unsettled], stale, profiles)
    expect(result).toHaveLength(0)
  })

  it('skips records without payable wage', () => {
    const settledZeroPay = {
      date: '2026-08-18',
      hours: 8,
      remark: '',
      settled: true as const,
    }
    const result = syncWageEntries([settledZeroPay], [], []) // 无工作时薪 → 0 工资
    expect(result).toHaveLength(0)
  })
})
