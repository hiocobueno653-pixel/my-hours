import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { shiftDate, todayISO } from '../data/dates'
import { useAppStore } from '../store/useAppStore'
import { DayEditor } from './DayEditor'

describe('DayEditor future-date guard', () => {
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

  it('does not move to tomorrow from today', async () => {
    const onNextDay = vi.fn()
    render(<DayEditor date={todayISO()} onClose={vi.fn()} onNextDay={onNextDay} />)

    await userEvent.click(screen.getByRole('button', { name: '后一天' }))
    expect(onNextDay).not.toHaveBeenCalled()
  })

  it('rejects saving a future date', async () => {
    const tomorrow = shiftDate(todayISO(), 1)
    render(<DayEditor date={tomorrow} onClose={vi.fn()} />)

    await userEvent.type(screen.getAllByRole('spinbutton')[0], '8')
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(screen.getByText('不能记录未来日期')).toBeInTheDocument()
    expect(useAppStore.getState().records).toHaveLength(0)
  })
})
