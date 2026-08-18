import { describe, expect, it } from 'vitest'
import {
  formatMonthLabel,
  getMonthDates,
  parseMonthKey,
  shiftDate,
  shiftMonth,
  weekdayName,
} from './dates'

describe('date utilities', () => {
  it('returns dates and weekday names for a month', () => {
    const dates = getMonthDates('2026-08')
    expect(dates).toHaveLength(31)
    expect(dates[0]).toMatchObject({ date: '2026-08-01', day: 1, weekday: 6 })
    expect(weekdayName(6)).toBe('六')
  })

  it('handles leap month lengths', () => {
    expect(getMonthDates('2026-02')).toHaveLength(28)
    expect(getMonthDates('2028-02')).toHaveLength(29)
  })

  it('shifts dates across month boundaries', () => {
    expect(shiftDate('2026-08-01', -1)).toBe('2026-07-31')
    expect(shiftDate('2026-12-31', 1)).toBe('2027-01-01')
  })

  it('shifts months across years', () => {
    expect(shiftMonth('2026-01', -1)).toBe('2025-12')
    expect(shiftMonth('2026-12', 1)).toBe('2027-01')
  })

  it('formats month labels and parses keys', () => {
    expect(formatMonthLabel('2026-08')).toBe('2026年8月')
    expect(parseMonthKey('2026-08')).toEqual({ year: 2026, month: 8 })
    expect(parseMonthKey('bad')).toBeNull()
  })
})
