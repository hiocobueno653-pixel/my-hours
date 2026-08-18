import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import {
  currentMonthKey,
  formatDateLabel,
  shiftDate,
  todayISO,
} from '../data/dates'
import { useAppStore } from '../store/useAppStore'
import { OverviewView } from './OverviewView'

describe('overview UI', () => {
  beforeEach(() => {
    window.localStorage.clear()
    useAppStore.setState({
      records: [],
      entries: [],
      customCategories: [],
      workProfiles: [{ id: 'work-default', name: '默认工作', hourlyRate: 0 }],
      budgetTargets: { monthlyExpenseBudget: 0, monthlyIncomeGoal: 0 },
    })
  })

  it('defaults to today when viewing the current month', () => {
    render(
      <OverviewView
        yearMonth={currentMonthKey()}
        onYearMonthChange={vi.fn()}
        onOpenDay={vi.fn()}
      />,
    )

    expect(
      screen.getByRole('region', {
        name: `${formatDateLabel(todayISO())}详情`,
      }),
    ).toBeInTheDocument()
  })

  it('shows a selected day detail without switching pages and opens editing from detail', async () => {
    const date = shiftDate(todayISO(), -1)
    useAppStore.setState({
      records: [{ date, hours: 8, remark: '晚班' }],
      entries: [
        {
          id: 'entry-1',
          date,
          type: 'income',
          amount: 200,
          category: '工资',
          remark: '',
          workDate: date,
        },
      ],
    })
    const onOpenDay = vi.fn()

    render(
      <OverviewView
        yearMonth={currentMonthKey()}
        onYearMonthChange={vi.fn()}
        onOpenDay={onOpenDay}
      />,
    )

    await userEvent.click(screen.getByRole('button', { name: new RegExp(date) }))
    expect(onOpenDay).not.toHaveBeenCalled()

    const detail = screen.getByRole('region', {
      name: `${formatDateLabel(date)}详情`,
    })
    expect(within(detail).getByText('8')).toBeInTheDocument()
    expect(within(detail).getByText('晚班')).toBeInTheDocument()
    expect(within(detail).getByText('工资')).toBeInTheDocument()

    await userEvent.click(within(detail).getByRole('button', { name: '修改记录' }))
    expect(onOpenDay).toHaveBeenCalledWith(date)
  })
})
