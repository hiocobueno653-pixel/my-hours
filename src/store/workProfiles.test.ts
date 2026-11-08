import { beforeEach, describe, expect, it } from 'vitest'
import { useAppStore } from './useAppStore'

describe('work profile uniqueness', () => {
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

  it('rejects a custom work named like the default work', () => {
    const saved = useAppStore.getState().saveWorkProfile({
      id: 'work-duplicate',
      name: '默认工作',
      hourlyRate: 30,
    })

    expect(saved).toBe(false)
    expect(useAppStore.getState().workProfiles).toHaveLength(1)
  })

  it('rejects duplicate custom work names on edit', () => {
    useAppStore.getState().saveWorkProfile({
      id: 'work-a',
      name: '工地A',
      hourlyRate: 25,
    })
    const saved = useAppStore.getState().saveWorkProfile({
      id: 'work-b',
      name: '工地A',
      hourlyRate: 30,
    })

    expect(saved).toBe(false)
    expect(useAppStore.getState().workProfiles).toHaveLength(2)
  })
})
