import { describe, expect, it } from 'vitest'
import {
  DEFAULT_BUDGET_TARGETS,
  DEFAULT_WORK_ID,
  ensureDefaultWorkProfile,
  getRecordPay,
  normalizeBudgetTargets,
  normalizeWorkProfile,
  parseBudgetInput,
  parseRateInput,
} from './profiles'

describe('parseRateInput', () => {
  it('accepts empty as unset (0)', () => {
    expect(parseRateInput('')).toEqual({ ok: true, rate: 0 })
  })
  it('accepts decimal rates', () => {
    expect(parseRateInput('18.5')).toEqual({ ok: true, rate: 18.5 })
  })
  it('rejects out-of-range or invalid rates', () => {
    expect(parseRateInput('abc').ok).toBe(false)
    expect(parseRateInput('-1').ok).toBe(false)
    expect(parseRateInput('100000').ok).toBe(false)
  })
})

describe('normalizeWorkProfile', () => {
  it('keeps the default work entry', () => {
    const parsed = normalizeWorkProfile({ id: DEFAULT_WORK_ID, name: '默认工作', hourlyRate: 20 })
    expect(parsed).toEqual({ id: DEFAULT_WORK_ID, name: '默认工作', hourlyRate: 20 })
  })
  it('rejects invalid profiles', () => {
    expect(normalizeWorkProfile(null)).toBeNull()
    expect(normalizeWorkProfile({ id: '', name: 'x', hourlyRate: 1 })).toBeNull()
    expect(normalizeWorkProfile({ id: 'w1', name: '', hourlyRate: 1 })).toBeNull()
    expect(normalizeWorkProfile({ id: 'w1', name: 'x', hourlyRate: -2 })).toBeNull()
  })
})

describe('ensureDefaultWorkProfile', () => {
  it('injects default work when missing', () => {
    const result = ensureDefaultWorkProfile([{ id: 'w1', name: '工地', hourlyRate: 30 }])
    expect(result[0].id).toBe(DEFAULT_WORK_ID)
    expect(result.length).toBe(2)
  })
  it('dedupes by id', () => {
    const result = ensureDefaultWorkProfile([
      { id: 'w1', name: 'a', hourlyRate: 1 },
      { id: 'w1', name: 'b', hourlyRate: 2 },
    ])
    expect(result.filter((p) => p.id === 'w1')).toHaveLength(1)
  })
})

describe('getRecordPay', () => {
  it('computes pay from the rate snapshot', () => {
    expect(getRecordPay({ date: '2026-08-01', hours: 8, remark: '', rate: 20 })).toBe(160)
    expect(getRecordPay({ date: '2026-08-01', hours: 8.5, remark: '', rate: 12.5 })).toBe(106.25)
  })
  it('returns 0 when no rate is set', () => {
    expect(getRecordPay({ date: '2026-08-01', hours: 8, remark: '' })).toBe(0)
  })
})

describe('budget targets', () => {
  it('normalizes budget values', () => {
    expect(normalizeBudgetTargets({ monthlyExpenseBudget: 3000, monthlyIncomeGoal: '9000' })).toEqual({
      monthlyExpenseBudget: 3000,
      monthlyIncomeGoal: 9000,
    })
    expect(normalizeBudgetTargets({ monthlyExpenseBudget: -5, monthlyIncomeGoal: 'x' })).toEqual(
      DEFAULT_BUDGET_TARGETS,
    )
  })
  it('parses budget input with empty as 0', () => {
    expect(parseBudgetInput('')).toEqual({ ok: true, amount: 0 })
    expect(parseBudgetInput('3500.5')).toEqual({ ok: true, amount: 3500.5 })
    expect(parseBudgetInput('0.00').ok).toBe(false)
    expect(parseBudgetInput('abc').ok).toBe(false)
  })
})
