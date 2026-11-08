import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useAppStore } from '../store/useAppStore'
import { DayEditor } from './DayEditor'

describe('DayEditor wage sync', () => {
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

  it('updates rather than deletes the auto wage entry when saving', async () => {
    const date = '2026-08-01'
    useAppStore.setState({
      records: [{ date, hours: 8, remark: '', rate: 50, settled: true }],
      entries: [{
        id: `wage-${date}`,
        date,
        type: 'income' as const,
        amount: 400,
        category: '工资',
        remark: '结算工资',
        workDate: date,
      }],
    })
    render(
      <DayEditor
        date={date}
        record={{ date, hours: 8, remark: '', rate: 50, settled: true }}
        onClose={vi.fn()}
      />,
    )

    await userEvent.clear(screen.getAllByRole('spinbutton')[0])
    await userEvent.type(screen.getAllByRole('spinbutton')[0], '9')
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(useAppStore.getState().records[0]).toMatchObject({
      hours: 9,
      rate: 50,
      settled: true,
    })
    expect(useAppStore.getState().entries).toHaveLength(1)
    expect(useAppStore.getState().entries[0].amount).toBe(450)
  })

  it('previews hours × rate and enables settle when custom pay is empty', async () => {
    render(<DayEditor date="2026-08-02" onClose={vi.fn()} />)

    const inputs = screen.getAllByRole('spinbutton')
    await userEvent.type(inputs[0], '8')

    // 留空自动计算：预览 = 8h × 20 = 160，结算开关可用
    const totalLabel = screen.getByText('本日工资')
    const totalValue = totalLabel.closest('div')!.querySelector('strong')!.textContent
    expect(totalValue).toBe('¥160')
    const settle = screen.getByRole('checkbox', { name: /已结算/ })
    expect(settle).toBeEnabled()

    await userEvent.click(settle)
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(useAppStore.getState().records[0]).toMatchObject({
      hours: 8,
      settled: true,
    })
    expect(useAppStore.getState().entries[0]).toMatchObject({
      id: 'wage-2026-08-02',
      amount: 160,
      type: 'income',
    })
  })

  it('rejects invalid custom pay format and shows error message', async () => {
    render(<DayEditor date="2026-08-03" onClose={vi.fn()} />)

    const inputs = screen.getAllByRole('spinbutton')
    await userEvent.type(inputs[0], '8')
    await userEvent.type(inputs[1], '300.555')
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(screen.getByText('当日工资最多两位小数')).toBeInTheDocument()
    expect(useAppStore.getState().records).toHaveLength(0)
  })
})
