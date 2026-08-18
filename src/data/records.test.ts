import { describe, expect, it } from 'vitest'
import {
  formatHours,
  getMonthSummary,
  normalizeRecord,
  parseHoursInput,
} from './records'

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
