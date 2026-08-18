import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import {
  currentMonthKey,
  formatDateLabel,
  formatMonthLabel,
  todayISO,
} from '../data/dates'
import { useAppStore } from '../store/useAppStore'
import { DayEditor } from './DayEditor'
import { MonthView } from './MonthView'

describe('month UI', () => {
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

  it('renders the current month heading', () => {
    render(<MonthView />)
    expect(
      screen.getByRole('heading', { name: formatMonthLabel(currentMonthKey()) }),
    ).toBeInTheDocument()
  })

  it('shows today as a separate workspace and keeps other days in the list', () => {
    render(<MonthView />)
    const today = todayISO()
    const day = Number(today.slice(-2))
    const weekday = ['日', '一', '二', '三', '四', '五', '六'][
      new Date(`${today}T00:00:00`).getDay()
    ]
    const todayRegion = screen.getByRole('region', { name: '今天' })
    expect(within(todayRegion).getByText(formatDateLabel(today))).toBeInTheDocument()
    expect(within(todayRegion).getByRole('button', { name: '记工时' })).toBeInTheDocument()

    const daysRegion = screen.getByRole('region', { name: '本月其他日期' })
    expect(
      within(daysRegion).queryByRole('button', {
        name: `${day}周${weekday}`,
      }),
    ).not.toBeInTheDocument()
    expect(
      within(daysRegion).getByRole('button', { name: /1周六/ }),
    ).toBeInTheDocument()
  })

  it('saves a day record from the editor', async () => {
    const onClose = vi.fn()
    render(<DayEditor date="2026-08-01" onClose={onClose} />)

    await userEvent.type(screen.getByRole('spinbutton'), '8.5')
    await userEvent.type(screen.getByRole('textbox'), '上午')
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(onClose).toHaveBeenCalled()
    expect(useAppStore.getState().records).toEqual([
      { date: '2026-08-01', hours: 8.5, remark: '上午' },
    ])
  })

  it('shows validation feedback when hours are empty', async () => {
    render(<DayEditor date="2026-08-01" onClose={vi.fn()} />)
    await userEvent.click(screen.getByRole('button', { name: '保存' }))
    expect(screen.getByText('请填写工时')).toBeInTheDocument()
  })

  it('saves work hours and linked income together', async () => {
    render(<DayEditor date="2026-08-01" onClose={vi.fn()} />)

    await userEvent.type(screen.getByRole('spinbutton'), '8.5')
    await userEvent.click(screen.getByRole('checkbox', { name: '同时记收入' }))
    await userEvent.click(screen.getByRole('button', { name: '¥200' }))
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(useAppStore.getState().records).toEqual([
      { date: '2026-08-01', hours: 8.5, remark: '' },
    ])
    expect(useAppStore.getState().entries).toContainEqual(
      expect.objectContaining({
        date: '2026-08-01',
        type: 'income',
        amount: 200,
        workDate: '2026-08-01',
      }),
    )
  })

  it('updates one linked income instead of duplicating it', async () => {
    const date = '2026-08-01'
    useAppStore.setState({
      records: [{ date, hours: 8, remark: '' }],
      entries: [
        {
          id: 'income-1',
          date,
          type: 'income',
          amount: 100,
          category: '工资',
          remark: '',
          workDate: date,
        },
      ],
    })
    render(
      <DayEditor
        date={date}
        record={{ date, hours: 8, remark: '' }}
        onClose={vi.fn()}
      />,
    )

    const amountInputs = screen.getAllByRole('spinbutton')
    await userEvent.clear(amountInputs[1])
    await userEvent.type(amountInputs[1], '200')
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(useAppStore.getState().entries).toHaveLength(1)
    expect(useAppStore.getState().entries[0]).toMatchObject({
      id: 'income-1',
      amount: 200,
      workDate: date,
    })
  })

  it('restores a deleted day record from undo', async () => {
    useAppStore.setState({
      records: [{ date: '2026-08-01', hours: 8, remark: '早班' }],
    })
    render(<MonthView />)

    await userEvent.click(screen.getByRole('button', { name: /1周六/ }))
    await userEvent.click(screen.getByRole('button', { name: '删除' }))
    const dialog = screen.getByRole('alertdialog')
    await userEvent.click(within(dialog).getByRole('button', { name: '删除' }))

    expect(screen.getByText('已删除这天的记录')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: '撤销' }))
    expect(useAppStore.getState().records).toEqual([
      { date: '2026-08-01', hours: 8, remark: '早班' },
    ])
  })

  it('deletes and restores the income linked to a day record together', async () => {
    const date = '2026-08-01'
    const linkedIncome = {
      id: 'income-linked',
      date,
      type: 'income' as const,
      amount: 200,
      category: '工资',
      remark: '',
      workDate: date,
    }
    useAppStore.setState({
      records: [{ date, hours: 8, remark: '' }],
      entries: [linkedIncome],
    })
    render(<MonthView />)

    await userEvent.click(screen.getByRole('button', { name: /1周六/ }))
    await userEvent.click(screen.getByRole('button', { name: '删除' }))
    const dialog = screen.getByRole('alertdialog')
    await userEvent.click(within(dialog).getByRole('button', { name: '删除' }))

    expect(useAppStore.getState().records).toHaveLength(0)
    expect(useAppStore.getState().entries).toHaveLength(0)
    await userEvent.click(screen.getByRole('button', { name: '撤销' }))
    expect(useAppStore.getState().records).toHaveLength(1)
    expect(useAppStore.getState().entries).toContainEqual(linkedIncome)
  })

  it('shows saved feedback after saving a day', async () => {
    render(<MonthView />)
    await userEvent.click(screen.getByRole('button', { name: /1周六/ }))
    await userEvent.click(screen.getByRole('button', { name: '8.5小时' }))
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(await screen.findByText('已保存')).toBeInTheDocument()
  })

  it('saves a quick hour preset without typing', async () => {
    render(<DayEditor date="2026-08-01" onClose={vi.fn()} />)

    await userEvent.click(screen.getByRole('button', { name: '8.5小时' }))
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(useAppStore.getState().records).toEqual([
      { date: '2026-08-01', hours: 8.5, remark: '' },
    ])
  })

  it('confirms before deleting a day record', async () => {
    useAppStore.setState({
      records: [{ date: '2026-08-01', hours: 8, remark: '早班' }],
    })
    render(
      <DayEditor
        date="2026-08-01"
        record={{ date: '2026-08-01', hours: 8, remark: '早班' }}
        onClose={vi.fn()}
      />,
    )

    await userEvent.click(screen.getByRole('button', { name: '删除' }))
    const dialog = screen.getByRole('alertdialog')
    expect(within(dialog).getByText('删除这天的记录？')).toBeInTheDocument()

    await userEvent.click(within(dialog).getByRole('button', { name: '取消' }))
    expect(useAppStore.getState().records).toHaveLength(1)
  })

  it('shows a ledger count for a day with linked entries', () => {
    const date = todayISO()
    useAppStore.setState({
      records: [{ date, hours: 8, remark: '' }],
      entries: [
        {
          id: 'entry-1',
          date,
          type: 'expense',
          amount: 20,
          category: '餐饮',
          remark: '',
          workDate: date,
        },
      ],
    })
    render(<MonthView />)
    const todayRegion = screen.getByRole('region', { name: '今天' })
    expect(within(todayRegion).getByText('餐饮')).toBeInTheDocument()
    expect(within(todayRegion).getByText('-¥20')).toBeInTheDocument()
  })
})
