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
} from '../data/dates'
import {
  formatMoney,
  getLedgerMonthEntries,
  getLedgerMonthSummary,
} from '../data/ledger'
import { formatHours, getRecordByDate } from '../data/records'
import { exportLedgerCsv, exportLedgerExcel } from '../services/exportService'
import { useAppStore } from '../store/useAppStore'
import type { LedgerEntry } from '../data/types'
import { CategoryManager } from './CategoryManager'
import { LedgerEditor } from './LedgerEditor'
import { useModalLayer } from '../navigation/backNavigation'

export function LedgerView() {
  const entries = useAppStore((state) => state.entries)
  const records = useAppStore((state) => state.records)
  const [yearMonth, setYearMonth] = useState(currentMonthKey)
  const [editorOpen, setEditorOpen] = useState(false)
  const [selectedEntry, setSelectedEntry] = useState<LedgerEntry | undefined>()
  const [exportState, setExportState] = useState('')
  const [savedMessage, setSavedMessage] = useState('')
  const [undoEntry, setUndoEntry] = useState<LedgerEntry | null>(null)

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
  const [query, setQuery] = useState('')
  useModalLayer(() => setExportMenuOpen(false), exportMenuOpen)

  const monthEntries = useMemo(
    () => getLedgerMonthEntries(entries, yearMonth),
    [entries, yearMonth],
  )
  const filteredEntries = useMemo(() => {
    const keyword = query.trim().toLowerCase()
    if (!keyword) return monthEntries
    return monthEntries.filter((entry) => {
      const dateDay = Number(entry.date.slice(-2))
      const dayText = String(dateDay)
      return (
        entry.category.toLowerCase().includes(keyword) ||
        entry.remark.toLowerCase().includes(keyword) ||
        dayText.includes(keyword)
      )
    })
  }, [monthEntries, query])
  const summary = useMemo(
    () => getLedgerMonthSummary(entries, yearMonth),
    [entries, yearMonth],
  )

  const openNew = () => {
    setSelectedEntry(undefined)
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
      <header className="screen-header ledger-screen-header">
        <div className="screen-header-copy">
          <span className="screen-kicker">收支记录</span>
          <h1>记账</h1>
        </div>
        <div className="screen-header-actions">
          <button
            type="button"
            className="icon-button"
            onClick={() => setManagerOpen(true)}
            aria-label="管理分类"
            title="管理分类"
          >
            <Tags size={20} />
          </button>
          <button
            type="button"
            className="icon-button export-button"
            onClick={() => setExportMenuOpen(true)}
            aria-label="导出账本"
            title="导出账本"
          >
            <Download size={20} />
          </button>
        </div>
      </header>

      <div className="month-switcher" aria-label="月份切换">
        <button
          type="button"
          className="icon-button"
          onClick={() => setYearMonth((current) => shiftMonth(current, -1))}
          aria-label="上个月"
        >
          <ChevronLeft size={22} />
        </button>
        <h2 className="month-switcher-label">{formatMonthLabel(yearMonth)}</h2>
        <button
          type="button"
          className="icon-button"
          onClick={() => setYearMonth((current) => shiftMonth(current, 1))}
          aria-label="下个月"
        >
          <ChevronRight size={22} />
        </button>
      </div>

      <div className="page-intro ledger-intro">
        <div>
          <strong>每一笔收支都记在这里</strong>
          <span>点开账目可以修改分类或关联工时</span>
        </div>
        <span className="ledger-entry-count">本月 {monthEntries.length} 笔</span>
      </div>

      <label className="search-box">
        <Search size={17} aria-hidden="true" />
        <input
          type="search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="搜索分类、备注或日期（如 5）"
          aria-label="搜索账目"
        />
        {query ? (
          <button
            type="button"
            className="search-clear"
            onClick={() => setQuery('')}
            aria-label="清除搜索"
          >
            ×
          </button>
        ) : null}
      </label>

      <section className="summary-strip ledger-summary" aria-label="本月账目">
        <div className="summary-item income">
          <span>收入</span>
          <strong>¥{formatMoney(summary.income)}</strong>
        </div>
        <div className="summary-item expense">
          <span>支出</span>
          <strong>¥{formatMoney(summary.expense)}</strong>
        </div>
        <div className={`summary-item balance${summary.balance < 0 ? ' negative' : ''}`}>
          <span>结余</span>
          <strong>
            {summary.balance < 0 ? '-' : ''}¥{formatMoney(Math.abs(summary.balance))}
          </strong>
        </div>
      </section>

      <button type="button" className="button primary full add-entry" onClick={openNew}>
        <Plus size={18} />
        记一笔
      </button>

      <section className="ledger-list">
        {query.trim() ? (
          <p className="search-summary">
            找到 {filteredEntries.length} 笔{filteredEntries.length !== monthEntries.length ? `（共 ${monthEntries.length} 笔）` : ''}
          </p>
        ) : null}
        {filteredEntries.length > 0 ? (
          filteredEntries.map((entry, index) => {
            const linkedRecord = entry.workDate
              ? getRecordByDate(records, entry.workDate)
              : undefined
            return (
              <button
                type="button"
                key={entry.id}
                className="ledger-row"
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
        <div className="sheet-backdrop" onClick={() => setExportMenuOpen(false)}>
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

      {editorOpen ? (
        <LedgerEditor
          entry={selectedEntry}
          onClose={() => setEditorOpen(false)}
          onSaved={() => setSavedMessage('已保存')}
          onDeleted={(entry) => setUndoEntry(entry)}
        />
      ) : null}
    </div>
  )
}
