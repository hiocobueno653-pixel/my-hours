import { fireEvent, render, screen, within } from '@testing-library/react'
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

// 夹具固定在 2026-08（8/1 为周六）；冻结「今天」避免真实时钟推移
// 让「当前月」漂离夹具月份（例如 10 月时 /1周六/ 只匹配到被禁用的未来日）
vi.mock('../data/dates', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../data/dates')>()
  return {
    ...actual,
    todayISO: () => '2026-08-15',
    currentMonthKey: () => '2026-08',
  }
})

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

    const calendarRegion = screen.getByRole('region', { name: '本月日历' })
    expect(
      within(calendarRegion).getByRole('button', {
        name: new RegExp(`^${day}周${weekday}`),
      }),
    ).toBeInTheDocument()
    expect(
      within(calendarRegion).getByRole('button', { name: /1周六/ }),
    ).toBeInTheDocument()
  })

  it('saves a day record from the editor', async () => {
    const onClose = vi.fn()
    render(<DayEditor date="2026-08-01" onClose={onClose} />)

    await userEvent.type(screen.getAllByRole('spinbutton')[0], '8.5')
    // 备注走 change 事件：userEvent.type 在高负载下偶发丢字符，
    // 本用例验证的是「保存记录」而非打字机行为
    fireEvent.change(screen.getByRole('textbox'), { target: { value: '上午' } })
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

  it('saves work hours without creating income entries', async () => {
    render(<DayEditor date="2026-08-01" onClose={vi.fn()} />)

    await userEvent.type(screen.getAllByRole('spinbutton')[0], '8.5')
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(useAppStore.getState().records).toEqual([
      { date: '2026-08-01', hours: 8.5, remark: '' },
    ])
    expect(useAppStore.getState().entries).toHaveLength(0)
  })

  it('removes old linked income when saving a record', async () => {
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

    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    // 旧的关联收入应被清除（工资由工时×时薪自动计算，不再手动记收入）
    expect(useAppStore.getState().entries).toHaveLength(0)
  })

  it('restores a deleted day record from undo', async () => {
    useAppStore.setState({
      records: [{ date: '2026-08-01', hours: 8, remark: '早班' }],
    })
    render(<MonthView />)

    await userEvent.click(screen.getByRole('button', { name: /1周六/ }))
    await userEvent.click(screen.getByRole('button', { name: '修改' }))
    await userEvent.click(screen.getByRole('button', { name: '删除' }))
    const dialog = screen.getByRole('alertdialog')
    await userEvent.click(within(dialog).getByRole('button', { name: '确认' }))

    expect(screen.getByText('已删除这天的记录')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: '撤销' }))
    expect(useAppStore.getState().records).toEqual([
      { date: '2026-08-01', hours: 8, remark: '早班' },
    ])
  })

  it('restores rate, workId and settled when undoing a delete', async () => {
    useAppStore.setState({
      records: [
        {
          date: '2026-08-01',
          hours: 8,
          remark: '早班',
          rate: 50,
          fixedPay: 450,
          workId: 'work-a',
          settled: true,
        },
      ],
    })
    render(<MonthView />)

    await userEvent.click(screen.getByRole('button', { name: /1周六/ }))
    await userEvent.click(screen.getByRole('button', { name: '修改' }))
    await userEvent.click(screen.getByRole('button', { name: '删除' }))
    const dialog = screen.getByRole('alertdialog')
    await userEvent.click(within(dialog).getByRole('button', { name: '确认' }))

    await userEvent.click(screen.getByRole('button', { name: '撤销' }))
    expect(useAppStore.getState().records).toEqual([
      {
        date: '2026-08-01',
        hours: 8,
        remark: '早班',
        rate: 50,
        fixedPay: 450,
        workId: 'work-a',
        settled: true,
      },
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
    await userEvent.click(screen.getByRole('button', { name: '修改' }))
    await userEvent.click(screen.getByRole('button', { name: '删除' }))
    const dialog = screen.getByRole('alertdialog')
    await userEvent.click(within(dialog).getByRole('button', { name: '确认' }))

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
