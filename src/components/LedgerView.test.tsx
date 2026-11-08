import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { currentMonthKey, formatMonthLabel } from '../data/dates'
import { useAppStore } from '../store/useAppStore'
import { LedgerView } from './LedgerView'

// 账目夹具固定在 2026-08；冻结「今天」让默认展示月与夹具月份一致，
// 不随真实时钟漂移（否则 8 月账目在 10 月的账本里不可见）
vi.mock('../data/dates', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../data/dates')>()
  return {
    ...actual,
    todayISO: () => '2026-08-15',
    currentMonthKey: () => '2026-08',
  }
})

describe('ledger UI', () => {
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

  it('renders the current ledger month and adds an entry', async () => {
    render(<LedgerView />)
    expect(
      screen.getByRole('heading', { name: formatMonthLabel(currentMonthKey()) }),
    ).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: '记一笔' }))
    const amountInput = screen.getByRole('spinbutton')
    await userEvent.type(amountInput, '35.5')
    await userEvent.type(
      screen.getByRole('textbox', { name: /备注/ }),
      '午饭',
    )
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(useAppStore.getState().entries).toHaveLength(1)
    expect(screen.getAllByText('餐饮').length).toBeGreaterThan(0)
    expect(screen.getAllByText('-35.5').length).toBeGreaterThan(0)
  })

  it('shows amount validation feedback', async () => {
    render(<LedgerView />)
    await userEvent.click(screen.getByRole('button', { name: '记一笔' }))
    await userEvent.click(screen.getByRole('button', { name: '保存' }))
    expect(screen.getByText('请填写金额')).toBeInTheDocument()
  })

  it('opens category management and adds a custom category', async () => {
    render(<LedgerView />)
    await userEvent.click(screen.getByRole('button', { name: '管理分类' }))
    await userEvent.type(
      screen.getByRole('textbox', { name: '新分类名称' }),
      '团建',
    )
    await userEvent.click(screen.getByRole('button', { name: '添加' }))
    expect(useAppStore.getState().customCategories).toEqual([
      expect.objectContaining({ name: '团建', type: 'expense' }),
    ])
  })

  it('shows linked work hours on a ledger entry', () => {
    useAppStore.setState({
      records: [{ date: '2026-08-01', hours: 8, remark: '早班' }],
      entries: [
        {
          id: 'entry-1',
          date: '2026-08-01',
          type: 'expense',
          amount: 20,
          category: '餐饮',
          remark: '',
          workDate: '2026-08-01',
        },
      ],
    })
    render(<LedgerView />)
    expect(screen.getByText('8小时')).toBeInTheDocument()
  })
})
