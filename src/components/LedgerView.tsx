import {
  ChevronLeft,
  ChevronRight,
  Download,
  FileDown,
  FileSpreadsheet,
  Plus,
  Search,
  Tags,
  WalletCards,
  X,
} from 'lucide-react'
import { useEffect, useMemo, useState, type CSSProperties } from 'react'
import {
  currentMonthKey,
  formatMonthLabel,
  shiftMonth,
  todayISO,
} from '../data/dates'
import {
  formatMoney,
  getLedgerMonthEntries,
  getLedgerMonthSummary,
} from '../data/ledger'
import { formatHours } from '../data/records'
import { exportLedgerCsv, exportLedgerExcel } from '../services/exportService'
import { useAppStore } from '../store/useAppStore'
import type { LedgerEntry } from '../data/types'
import { CategoryManager } from './CategoryManager'
import { LedgerEditor } from './LedgerEditor'
import { MonthPicker } from './MonthPicker'
import { useModalLayer } from '../navigation/backNavigation'

export function LedgerView({
  initialEntryDate,
  onEntryHandled,
}: {
  initialEntryDate?: string | null
  onEntryHandled?: () => void
}) {
  const entries = useAppStore((state) => state.entries)
  const records = useAppStore((state) => state.records)
  const budgetTargets = useAppStore((state) => state.budgetTargets)
  const [yearMonth, setYearMonth] = useState(currentMonthKey)
  const [editorOpen, setEditorOpen] = useState(false)
  const [selectedEntry, setSelectedEntry] = useState<LedgerEntry | undefined>()
  const [entryInitialDate, setEntryInitialDate] = useState<string | undefined>()
  const [exportState, setExportState] = useState('')
  const [savedMessage, setSavedMessage] = useState('')
  const [undoEntry, setUndoEntry] = useState<LedgerEntry | null>(null)

  // 从记工页快捷记账：切到本页时预填日期并打开编辑器（仅一次）
  useEffect(() => {
    if (!initialEntryDate) return
    setYearMonth(initialEntryDate.slice(0, 7))
    setEntryInitialDate(initialEntryDate)
    setSelectedEntry(undefined)
    setEditorOpen(true)
  }, [initialEntryDate])

  const closeEditor = () => {
    setEditorOpen(false)
    setEntryInitialDate(undefined)
    onEntryHandled?.()
  }

  useEffect(() => {
    if (!savedMessage) return
    const timer = window.setTimeout(() => setSavedMessage(''), 2600)
    return () => window.clearTimeout(timer)
  }, [savedMessage])

  useEffect(() => {
    if (!undoEntry) return
    const timer = window.setTimeout(() => setUndoEntry(null), 6000)
    return () => window.clearTimeout(timer)
  }, [undoEntry])
  const [managerOpen, setManagerOpen] = useState(false)
  const [exportMenuOpen, setExportMenuOpen] = useState(false)
  const [monthPickerOpen, setMonthPickerOpen] = useState(false)
  const [query, setQuery] = useState('')
  const [categoryFilter, setCategoryFilter] = useState<string>('')
  const exportModal = useModalLayer(() => setExportMenuOpen(false), exportMenuOpen)

  const monthEntries = useMemo(
    () => getLedgerMonthEntries(entries, yearMonth),
    [entries, yearMonth],
  )
  const filteredEntries = useMemo(() => {
    const keyword = query.trim().toLowerCase()
    let list = monthEntries
    if (categoryFilter) {
      if (categoryFilter === 'income' || categoryFilter === 'expense') {
        list = list.filter((entry) => entry.type === categoryFilter)
      } else {
        list = list.filter((entry) => entry.category === categoryFilter)
      }
    }
    if (!keyword) return list
    return list.filter((entry) => {
      const dateDay = Number(entry.date.slice(-2))
      const dayText = String(dateDay)
      return (
        entry.category.toLowerCase().includes(keyword) ||
        entry.remark.toLowerCase().includes(keyword) ||
        dayText.includes(keyword)
      )
    })
  }, [monthEntries, query, categoryFilter])
  const summary = useMemo(
    () => getLedgerMonthSummary(entries, yearMonth),
    [entries, yearMonth],
  )
  const budget = budgetTargets.monthlyExpenseBudget
  const overBudget = budget > 0 && summary.expense > budget
  const overBudgetAmount = Math.round((summary.expense - budget) * 100) / 100
  // 分类筛选 chips：全部 + 收支类型 + 本月出现过的分类
  const filterChips = useMemo(() => {
    const chips: { key: string; label: string }[] = [
      { key: '', label: '全部' },
      { key: 'income', label: '收入' },
      { key: 'expense', label: '支出' },
    ]
    const seen = new Set<string>()
    for (const entry of monthEntries) {
      if (!seen.has(entry.category)) {
        seen.add(entry.category)
        chips.push({ key: entry.category, label: entry.category })
      }
    }
    return chips
  }, [monthEntries])
  const today = todayISO()
  const { todayEntries, todayIncome, todayExpense } = useMemo(() => {
    const todayEntries: LedgerEntry[] = []
    let income = 0
    let expense = 0
    for (const entry of entries) {
      if (entry.date === today) {
        todayEntries.push(entry)
        if (entry.type === 'income') income += entry.amount
        else expense += entry.amount
      }
    }
    return {
      todayEntries,
      todayIncome: Math.round(income * 100) / 100,
      todayExpense: Math.round(expense * 100) / 100,
    }
  }, [entries, today])

  const recordsByDate = useMemo(() => {
    const map = new Map<string, typeof records[number]>()
    for (const record of records) {
      map.set(record.date, record)
    }
    return map
  }, [records])

  const openNew = () => {
    setSelectedEntry(undefined)
    setEntryInitialDate(undefined)
    setEditorOpen(true)
  }

  const restoreDeletedEntry = () => {
    if (!undoEntry) return
    useAppStore.getState().saveLedgerEntry(undoEntry)
    setUndoEntry(null)
    setSavedMessage('已恢复')
  }

  const openEntry = (entry: LedgerEntry) => {
    setSelectedEntry(entry)
    setEditorOpen(true)
  }

  const handleExport = async () => {
    setExportState('导出中')
    try {
      await exportLedgerCsv(yearMonth, entries, records)
      setExportState('账本 CSV 已导出')
    } catch {
      setExportState('导出失败')
    }
  }

  const handleExportExcel = async () => {
    setExportState('导出中')
    try {
      await exportLedgerExcel(yearMonth, entries, records)
      setExportState('账本 Excel 已导出')
    } catch {
      setExportState('导出失败')
    }
  }

  return (
    <div className="ledger-view page-enter">
      <header className="ledger-page-header">
        <div className="ledger-heading-row">
          <div className="screen-header-copy">
            <span className="screen-kicker">收支记录</span>
            <h1>记账</h1>
          </div>
          <div className="header-tool-group">
            <div className="inline-month-nav" aria-label="月份切换">
              <button type="button" className="month-nav-button" onClick={() => setYearMonth((current) => shiftMonth(current, -1))} aria-label="上个月">
                <ChevronLeft size={19} />
              </button>
              <h2
                className="month-nav-label"
                tabIndex={0}
                title="选择月份"
                onClick={() => setMonthPickerOpen(true)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault()
                    setMonthPickerOpen(true)
                  }
                }}
              >
                {formatMonthLabel(yearMonth)}
              </h2>
              <button type="button" className="month-nav-button" onClick={() => setYearMonth((current) => shiftMonth(current, 1))} aria-label="下个月">
                <ChevronRight size={19} />
              </button>
            </div>
            <button type="button" className="icon-button quiet" onClick={() => setManagerOpen(true)} aria-label="管理分类" title="管理分类">
              <Tags size={19} />
            </button>
            <button type="button" className="icon-button quiet" onClick={() => setExportMenuOpen(true)} aria-label="导出账本" title="导出账本">
              <Download size={19} />
            </button>
          </div>
        </div>
      </header>

      <section className="ledger-overview" aria-label="本月账目">
        <div className="ledger-balance-block">
          <div className="ledger-balance-title">
            <span>本月结余</span>
            <button type="button" className="ledger-add-button" onClick={openNew}>
              <Plus size={18} />
              记一笔
            </button>
          </div>
          <strong className={summary.balance < 0 ? 'negative' : ''}>
            {summary.balance < 0 ? '-' : ''}¥{formatMoney(Math.abs(summary.balance))}
          </strong>
        </div>
        <div className="ledger-flow-pair">
          <div className="income">
            <span>收入</span>
            {/* 零值时省略正负号，避免出现「+¥0 / -¥0」的负零观感 */}
            <strong>{summary.income > 0 ? `+¥${formatMoney(summary.income)}` : '¥0'}</strong>
          </div>
          <div className="expense">
            <span>支出</span>
            <strong>{summary.expense > 0 ? `-¥${formatMoney(summary.expense)}` : '¥0'}</strong>
          </div>
        </div>
        <div className="ledger-overview-actions">
          <div className="ledger-today-line" aria-label="今天账目">
            <span>今天</span>
            {todayEntries.length > 0 ? (
              <>
                <small>{todayEntries.length} 笔</small>
                {todayIncome > 0 ? <strong className="income">+¥{formatMoney(todayIncome)}</strong> : null}
                {todayExpense > 0 ? <strong className="expense">-¥{formatMoney(todayExpense)}</strong> : null}
              </>
            ) : (
            <small>还没有账目</small>
          )}
        </div>
        </div>
      </section>

      {overBudget ? (
        <div className="over-budget-bar" role="alert">
          <span className="over-budget-icon" aria-hidden="true">!</span>
          <p>
            本月支出已超预算 <strong>¥{formatMoney(overBudgetAmount)}</strong>
            <small>预算 ¥{formatMoney(budget)}</small>
          </p>
        </div>
      ) : null}

      <section className="ledger-records" aria-label="账目明细">
        <div className="records-toolbar">
          <div>
            <strong>账目明细</strong>
            <small>{query.trim() ? `找到 ${filteredEntries.length} 笔` : `本月 ${monthEntries.length} 笔`}</small>
          </div>
        </div>
        {filterChips.length > 3 ? (
          <div className="filter-chips" role="group" aria-label="分类筛选">
            {filterChips.map((chip) => (
              <button
                type="button"
                key={chip.key}
                className={`filter-chip${categoryFilter === chip.key ? ' active' : ''}`}
                aria-pressed={categoryFilter === chip.key}
                onClick={() => setCategoryFilter(chip.key)}
              >
                {chip.label}
              </button>
            ))}
          </div>
        ) : null}
        <label className="search-box compact">
          <Search size={16} aria-hidden="true" />
          <input
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="搜索分类、备注或日期"
            aria-label="搜索账目"
          />
          {query ? (
            <button type="button" className="search-clear" onClick={() => setQuery('')} aria-label="清除搜索">×</button>
          ) : null}
        </label>
        <div className="ledger-list">
        {filteredEntries.length > 0 ? (
          filteredEntries.map((entry, index) => {
            const linkedRecord = entry.workDate
              ? recordsByDate.get(entry.workDate)
              : undefined
            return (
              <button
                type="button"
                key={entry.id}
                className={`ledger-row ${entry.type === 'income' ? 'income-row' : 'expense-row'}`}
                style={{ '--row-index': index } as CSSProperties}
                onClick={() => openEntry(entry)}
              >
                <span className="ledger-date">
                  {entry.date.slice(5).replace('-', '月')}日
                </span>
                <span className="ledger-main">
                  <strong>{entry.category}</strong>
                  {entry.remark ? <small>{entry.remark}</small> : null}
                  {linkedRecord ? (
                    <small className="linked-hours">
                      {formatHours(linkedRecord.hours)}小时
                    </small>
                  ) : null}
                </span>
                <span className={`ledger-amount ${entry.type}`}>
                  {entry.type === 'income' ? '+' : '-'}
                  {formatMoney(entry.amount)}
                </span>
              </button>
            )
          })
          ) : (
            <div className="empty-state">
              <span className="empty-state-icon">
                <WalletCards size={22} />
              </span>
              <strong>{query.trim() ? '没有匹配的账目' : '本月还没有账目'}</strong>
            </div>
          )}
        </div>
      </section>

      {undoEntry ? (
        <div className="undo-bar" role="status">
          <span>已删除这笔账</span>
          <button type="button" className="button" onClick={restoreDeletedEntry}>
            撤销
          </button>
        </div>
      ) : null}
      {savedMessage ? (
        <p className="status-line save-status" role="status">
          {savedMessage}
        </p>
      ) : null}
      {exportState ? (
        <p className="status-line" role="status">
          {exportState}
        </p>
      ) : null}

      {managerOpen ? (
        <CategoryManager onClose={() => setManagerOpen(false)} />
      ) : null}

      {exportMenuOpen ? (
        <div className="sheet-backdrop" ref={exportModal.containerRef} onClick={() => setExportMenuOpen(false)} onKeyDown={exportModal.onKeyDown}>
          <section
            className="action-sheet"
            role="dialog"
            aria-modal="true"
            aria-label="导出账本"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="sheet-header">
              <h2>导出账本</h2>
              <button
                type="button"
                className="icon-button"
                onClick={() => setExportMenuOpen(false)}
                aria-label="关闭"
              >
                <X size={20} />
              </button>
            </div>
            <p className="field-note">选择导出格式，文件会保存到本地或系统分享面板。</p>
            <div className="action-sheet-list">
              <button
                type="button"
                className="action-sheet-item"
                onClick={() => {
                  setExportMenuOpen(false)
                  void handleExport()
                }}
              >
                <span className="action-sheet-icon"><FileDown size={19} /></span>
                <span>
                  <strong>CSV 文件</strong>
                  <small>通用表格，邮箱/Excel 都能打开</small>
                </span>
              </button>
              <button
                type="button"
                className="action-sheet-item"
                onClick={() => {
                  setExportMenuOpen(false)
                  void handleExportExcel()
                }}
              >
                <span className="action-sheet-icon excel"><FileSpreadsheet size={19} /></span>
                <span>
                  <strong>Excel 表格 (.xlsx)</strong>
                  <small>带格式的电子表格，方便汇总处理</small>
                </span>
              </button>
            </div>
          </section>
        </div>
      ) : null}

      {monthPickerOpen ? (
        <MonthPicker
          value={yearMonth}
          onSelect={(next) => {
            setYearMonth(next)
            setMonthPickerOpen(false)
          }}
          onClose={() => setMonthPickerOpen(false)}
        />
      ) : null}

      {editorOpen ? (
        <LedgerEditor
          entry={selectedEntry}
          initialDate={entryInitialDate}
          onClose={closeEditor}
          onSaved={() => setSavedMessage('已保存')}
          onDeleted={(entry) => setUndoEntry(entry)}
        />
      ) : null}
    </div>
  )
}
