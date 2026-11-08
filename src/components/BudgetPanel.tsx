import { Pencil, WalletCards, X } from 'lucide-react'
import { useState } from 'react'
import { formatMoney, getLedgerMonthSummary } from '../data/ledger'
import { parseBudgetInput } from '../data/profiles'
import { useAppStore } from '../store/useAppStore'
import { ProgressBar } from './charts/ProgressBar'

interface BudgetPanelProps {
  yearMonth: string
}

export function BudgetPanel({ yearMonth }: BudgetPanelProps) {
  const entries = useAppStore((state) => state.entries)
  const budgetTargets = useAppStore((state) => state.budgetTargets)
  const saveBudgetTargets = useAppStore((state) => state.saveBudgetTargets)
  const summary = getLedgerMonthSummary(entries, yearMonth)
  const [editing, setEditing] = useState(false)
  const [budgetInput, setBudgetInput] = useState(
    budgetTargets.monthlyExpenseBudget > 0 ? String(budgetTargets.monthlyExpenseBudget) : '',
  )
  const [goalInput, setGoalInput] = useState(
    budgetTargets.monthlyIncomeGoal > 0 ? String(budgetTargets.monthlyIncomeGoal) : '',
  )
  const [error, setError] = useState('')

  const hasBudget = budgetTargets.monthlyExpenseBudget > 0
  const hasGoal = budgetTargets.monthlyIncomeGoal > 0
  const budgetOver = hasBudget && summary.expense > budgetTargets.monthlyExpenseBudget
  const goalReached = hasGoal && summary.income >= budgetTargets.monthlyIncomeGoal

  const startEdit = () => {
    setEditing(true)
    setBudgetInput(
      budgetTargets.monthlyExpenseBudget > 0 ? String(budgetTargets.monthlyExpenseBudget) : '',
    )
    setGoalInput(
      budgetTargets.monthlyIncomeGoal > 0 ? String(budgetTargets.monthlyIncomeGoal) : '',
    )
    setError('')
  }

  const save = () => {
    const budgetResult = parseBudgetInput(budgetInput)
    if (!budgetResult.ok) {
      setError(budgetResult.error)
      return
    }
    const goalResult = parseBudgetInput(goalInput)
    if (!goalResult.ok) {
      setError(goalResult.error)
      return
    }
    saveBudgetTargets({
      monthlyExpenseBudget: budgetResult.amount,
      monthlyIncomeGoal: goalResult.amount,
    })
    setEditing(false)
  }

  return (
    <section className="panel budget-panel" aria-label="预算与目标">
      <div className="section-heading my-section-heading">
        <div>
          <h3>预算与目标</h3>
          <span>本月支出预算与收入目标</span>
        </div>
        {!editing ? (
          <button type="button" className="icon-button" onClick={startEdit} aria-label="设置预算与目标" title="设置">
            <Pencil size={18} />
          </button>
        ) : null}
      </div>

      {editing ? (
        <div className="budget-editor">
          <label className="field">
            <span className="field-label">本月支出预算（留空不设）</span>
            <span className="input-with-prefix">
              <span className="field-prefix">¥</span>
              <input
                type="number"
                inputMode="decimal"
                min="0"
                step="0.01"
                value={budgetInput}
                onChange={(event) => {
                  setBudgetInput(event.target.value)
                  setError('')
                }}
                placeholder="0.00"
              />
            </span>
          </label>
          <label className="field">
            <span className="field-label">本月收入目标（留空不设）</span>
            <span className="input-with-prefix">
              <span className="field-prefix">¥</span>
              <input
                type="number"
                inputMode="decimal"
                min="0"
                step="0.01"
                value={goalInput}
                onChange={(event) => {
                  setGoalInput(event.target.value)
                  setError('')
                }}
                placeholder="0.00"
              />
            </span>
          </label>
          {error ? <p className="error-text">{error}</p> : null}
          <div className="sheet-actions budget-actions">
            <button type="button" className="button ghost" onClick={() => setEditing(false)}>
              <X size={16} />
              取消
            </button>
            <button type="button" className="button primary" onClick={save}>
              保存
            </button>
          </div>
        </div>
      ) : (
        <div className="budget-readout">
          <div className="budget-row">
            <div className="budget-row-head">
              <span>本月支出</span>
              <strong>
                ¥{formatMoney(summary.expense)}
                {hasBudget ? (
                  <span className="budget-limit"> / ¥{formatMoney(budgetTargets.monthlyExpenseBudget)}</span>
                ) : ''}
              </strong>
            </div>
            {hasBudget ? (
              <>
                <ProgressBar
                  value={summary.expense}
                  max={budgetTargets.monthlyExpenseBudget}
                  tone={budgetOver ? 'expense' : 'accent'}
                />
                <span className={budgetOver ? 'budget-hint over' : 'budget-hint'}>
                  {budgetOver ? '已超预算' : `已用 ${Math.round((summary.expense / budgetTargets.monthlyExpenseBudget) * 100)}%`}
                </span>
              </>
            ) : (
              <span className="budget-hint">未设预算，点击右上角设置</span>
            )}
          </div>
          <div className="budget-row">
            <div className="budget-row-head">
              <span>本月收入</span>
              <strong>
                ¥{formatMoney(summary.income)}
                {hasGoal ? (
                  <span className="budget-limit"> / ¥{formatMoney(budgetTargets.monthlyIncomeGoal)}</span>
                ) : ''}
              </strong>
            </div>
            {hasGoal ? (
              <>
                <ProgressBar
                  value={summary.income}
                  max={budgetTargets.monthlyIncomeGoal}
                  tone={goalReached ? 'income' : 'dark'}
                />
                <span className={goalReached ? 'budget-hint reached' : 'budget-hint'}>
                  {goalReached ? '目标已达成' : `已完成 ${Math.round((summary.income / budgetTargets.monthlyIncomeGoal) * 100)}%`}
                </span>
              </>
            ) : (
              <span className="budget-hint">未设目标，点击右上角设置</span>
            )}
          </div>
        </div>
      )}
      <div className="budget-tip">
        <WalletCards size={15} />
        预算与目标跟随「我的」页当前月份，可在记工/记账页随意切换月份。
      </div>
    </section>
  )
}
