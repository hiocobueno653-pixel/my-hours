import { beforeEach, describe, expect, it } from 'vitest'
import { useAppStore } from './useAppStore'

describe('wage ledger synchronization', () => {
  beforeEach(() => {
    window.localStorage.clear()
    useAppStore.setState({
      records: [],
      entries: [],
      customCategories: [],
      workProfiles: [{
        id: 'work-default',
        name: '默认工作',
        hourlyRate: 20,
      }],
      budgetTargets: { monthlyExpenseBudget: 0, monthlyIncomeGoal: 0 },
    })
  })

  it('creates the wage income when saving a settled record', () => {
    useAppStore.getState().saveDay(
      '2026-08-01',
      8,
      '',
      { rate: 50, settled: true },
    )

    expect(useAppStore.getState().entries).toEqual([
      {
        id: 'wage-2026-08-01',
        date: '2026-08-01',
        type: 'income',
        amount: 400,
        category: '工资',
        remark: '结算工资',
        workDate: '2026-08-01',
      },
    ])
  })

  it('updates and removes wage income when the settled status changes', () => {
    useAppStore.getState().saveDay(
      '2026-08-01',
      8,
      '',
      { rate: 50, settled: true },
    )
    useAppStore.getState().saveDay(
      '2026-08-01',
      9,
      '',
      { rate: 50, settled: true },
    )

    expect(useAppStore.getState().entries).toHaveLength(1)
    expect(useAppStore.getState().entries[0].amount).toBe(450)

    useAppStore.getState().saveDay(
      '2026-08-01',
      9,
      '',
      { rate: 50, settled: false },
    )
    expect(useAppStore.getState().records[0]).not.toHaveProperty('settled')
    expect(useAppStore.getState().entries).toHaveLength(0)
  })

  it('returns the removed wage entry when deleting a day', () => {
    useAppStore.getState().saveDay(
      '2026-08-01',
      8,
      '',
      { rate: 50, settled: true },
    )
    const removed = useAppStore.getState().deleteDay('2026-08-01')

    expect(removed?.id).toBe('wage-2026-08-01')
    expect(useAppStore.getState().entries).toHaveLength(0)
  })

  it('uses fixed daily pay when a record is settled', () => {
    useAppStore.getState().saveDay(
      '2026-08-01',
      8,
      '',
      { rate: 50, fixedPay: 350, settled: true },
    )
    expect(useAppStore.getState().entries[0].amount).toBe(350)
  })

  it('rejects out-of-range rate and fixed pay like import normalization', () => {
    // 超过上限的时薪/日薪不落库（与 normalizeRecord 的 MAX_* 口径一致）
    useAppStore.getState().saveDay('2026-08-01', 8, '', { rate: 999999 })
    expect(useAppStore.getState().records[0]).not.toHaveProperty('rate')

    useAppStore.getState().saveDay('2026-08-02', 8, '', { fixedPay: 1e12 })
    expect(useAppStore.getState().records[1]).not.toHaveProperty('fixedPay')
  })
})
