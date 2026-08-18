import { CalendarDays, ChevronLeft, ChevronRight, Download, FileDown, FileSpreadsheet, PenLine, Sparkles, X } from 'lucide-react'
import { useEffect, useMemo, useState, type CSSProperties } from 'react'
import {
  currentMonthKey,
  formatDateLabel,
  formatMonthLabel,
  getMonthDates,
  shiftDate,
  shiftMonth,
  todayISO,
  weekdayName,
} from '../data/dates'
import { formatMoney } from '../data/ledger'
import {
  formatHours,
  getMonthPay,
  getMonthSummary,
  getRecordByDate,
} from '../data/records'
import { exportMonthCsv, exportMonthExcel } from '../services/exportService'
import type { LedgerEntry, WorkDayRecord } from '../data/types'
import { useAppStore } from '../store/useAppStore'
import { haptic } from '../utils/haptics'
import { DayEditor } from './DayEditor'
import { useModalLayer } from '../navigation/backNavigation'

interface MonthViewProps {
  initialEditingDate?: string | null
  onEditorClosed?: () => void
}

export function MonthView({
  initialEditingDate,
  onEditorClosed,
}: MonthViewProps = {}) {
  const records = useAppStore((state) => state.records)
  const entries = useAppStore((state) => state.entries)
  const [yearMonth, setYearMonth] = useState(currentMonthKey)
  const [editingDate, setEditingDate] = useState<string | null>(initialEditingDate ?? null)
  const today = todayISO()
  const isCurrentMonth = yearMonth === today.slice(0, 7)

  useEffect(() => {
    if (initialEditingDate) {
      setEditingDate(initialEditingDate)
      setYearMonth(initialEditingDate.slice(0, 7))
    }
  }, [initialEditingDate])
  const [exportState, setExportState] = useState('')
  const [exportMenuOpen, setExportMenuOpen] = useState(false)
  useModalLayer(() => setExportMenuOpen(false), exportMenuOpen)
  const [savedMessage, setSavedMessage] = useState('')
  const [undoRecord, setUndoRecord] = useState<WorkDayRecord | null>(null)
  const [undoLinkedIncome, setUndoLinkedIncome] = useState<LedgerEntry | null>(null)

  useEffect(() => {
    if (!savedMessage) return
    const timer = window.setTimeout(() => setSavedMessage(''), 2600)
    return () => window.clearTimeout(timer)
  }, [savedMessage])

  useEffect(() => {
    if (!undoRecord) return
    const timer = window.setTimeout(() => {
      setUndoRecord(null)
      setUndoLinkedIncome(null)
    }, 6000)
    return () => window.clearTimeout(timer)
  }, [undoRecord])

  const dates = useMemo(() => getMonthDates(yearMonth), [yearMonth])
  const regularDates = useMemo(
    () => (isCurrentMonth ? dates.filter((day) => !day.isToday) : dates),
    [dates, isCurrentMonth],
  )
  const summary = useMemo(
    () => getMonthSummary(records, yearMonth),
    [records, yearMonth],
  )
  const monthPay = useMemo(
    () => getMonthPay(records, yearMonth),
    [records, yearMonth],
  )
  const unsettledCount = useMemo(() => {
    return records.filter(
      (record) =>
        record.date.startsWith(`${yearMonth}-`) &&
        record.hours * (record.rate ?? 0) > 0 &&
        !record.settled,
    ).length
  }, [records, yearMonth])
  const todayRecord = getRecordByDate(records, today)
  const todayEntries = entries.filter((entry) => entry.date === today)
  const todayIncome =
    Math.round(
      todayEntries
        .filter((entry) => entry.type === 'income')
        .reduce((sum, entry) => sum + entry.amount, 0) * 100,
    ) / 100
  const todayExpense =
    Math.round(
      todayEntries
        .filter((entry) => entry.type === 'expense')
        .reduce((sum, entry) => sum + entry.amount, 0) * 100,
    ) / 100
  const closeEditor = () => {
    setEditingDate(null)
    onEditorClosed?.()
  }

  const restoreDeleted = () => {
    if (!undoRecord) return
    useAppStore.getState().saveDay(
      undoRecord.date,
      undoRecord.hours,
      undoRecord.remark,
    )
    if (undoLinkedIncome) {
      useAppStore.getState().saveLedgerEntry(undoLinkedIncome)
    }
    setUndoRecord(null)
    setUndoLinkedIncome(null)
    setSavedMessage('已恢复')
    haptic()
  }

  const handleExport = async () => {
    setExportState('导出中')
    try {
      await exportMonthCsv(yearMonth, records)
      setExportState('CSV 已导出')
    } catch {
      setExportState('导出失败')
    }
  }

  const handleExportExcel = async () => {
    setExportState('导出中')
    try {
      await exportMonthExcel(yearMonth, records)
      setExportState('Excel 已导出')
    } catch {
      setExportState('导出失败')
    }
  }


  return (
    <div className="month-view page-enter">
      <header className="screen-header">
        <div className="screen-header-copy">
          <span className="screen-kicker">工作记录</span>
          <h1>记工</h1>
        </div>
        <div className="screen-header-actions">
          <button
            type="button"
            className="icon-button"
            onClick={() => setExportMenuOpen(true)}
            aria-label="导出工时表"
            title="导出工时表"
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
        {!isCurrentMonth ? (
          <button
            type="button"
            className="back-to-now"
            onClick={() => setYearMonth(currentMonthKey())}
          >
            <CalendarDays size={14} />
            回到本月
          </button>
        ) : null}
      </div>

      <section className="summary-strip work-summary" aria-label="月总计">
        <div className="summary-item">
          <span>月总计</span>
          <strong>{formatHours(summary.totalHours)}</strong>
          <small>小时</small>
        </div>
        <div className="summary-item">
          <span>工作天数</span>
          <strong>{summary.workDays}</strong>
          <small>天</small>
        </div>
        <div className="summary-item">
          <span>日均</span>
          <strong>{formatHours(summary.averageHours)}</strong>
          <small>小时</small>
        </div>
        <div className={`summary-item wage wide${monthPay > 0 ? ' has-wage' : ''}`}>
          <span>本月工资</span>
          <strong>¥{formatMoney(monthPay)}</strong>
          <small>{monthPay > 0 ? (unsettledCount > 0 ? `${unsettledCount} 笔待结算` : '已全部结算 ✓') : '未设时薪'}</small>
        </div>
      </section>

      {isCurrentMonth ? (
        <section className="today-card page-enter" aria-label="今天">
          <div className="today-card-header">
            <div className="today-title-block">
              <span className="today-kicker">今天 · 周{weekdayName(new Date(`${today}T00:00:00`).getDay())}</span>
              <strong>{formatDateLabel(today)}</strong>
            </div>
            <button
              type="button"
              className="button primary today-action"
              onClick={() => setEditingDate(today)}
            >
              <PenLine size={17} />
              {todayRecord ? '修改记录' : '记工时'}
            </button>
          </div>
          <div className="today-card-body">
            <div className="today-metric">
              <span>工时</span>
              <strong>{todayRecord ? formatHours(todayRecord.hours) : '--'}</strong>
              <small>小时</small>
            </div>
            <div className="today-metric">
              <span>收入</span>
              <strong>{todayIncome > 0 ? `¥${formatMoney(todayIncome)}` : '--'}</strong>
              <small>元</small>
            </div>
            <div className="today-metric">
              <span>账目</span>
              <strong>{todayEntries.length}</strong>
              <small>笔</small>
            </div>
          </div>
          {todayRecord?.remark ? <p className="today-remark">{todayRecord.remark}</p> : null}
          {!todayRecord && todayEntries.length === 0 ? (
            <p className="today-empty">今天还没有记录</p>
          ) : null}
          {todayIncome > 0 || todayExpense > 0 ? (
            <div className="today-entry-list">
              {todayEntries.map((entry) => (
                <button
                  type="button"
                  key={entry.id}
                  className={`today-entry-row ${entry.type}`}
                  onClick={() => setEditingDate(today)}
                  aria-label={`今天 ${entry.category} ${entry.type === 'income' ? '收入' : '支出'} ¥${formatMoney(entry.amount)}`}
                >
                  <span className="today-entry-category">{entry.category}</span>
                  <span className={`today-entry-amount ${entry.type}`}>
                    {entry.type === 'income' ? '+' : '-'}¥{formatMoney(entry.amount)}
                  </span>
                </button>
              ))}
            </div>
          ) : null}
        </section>
      ) : null}

      {records.length === 0 && isCurrentMonth ? (
        <aside className="onboarding-card" role="note">
          <Sparkles size={18} />
          <div>
            <strong>从今天开始记录</strong>
            <span>点上方「记工时」填工时，存下第一笔记录；再在「我的」页设个时薪，工资自动算。</span>
          </div>
        </aside>
      ) : null}

      <section
        className="day-list"
        aria-label={isCurrentMonth ? '本月其他日期' : '本月日期'}
      >
        <div className="day-list-heading">
          <span>{isCurrentMonth ? '本月其他日期' : '每日记录'}</span>
          <small>{regularDates.length}天</small>
        </div>
        {regularDates.map((day, index) => {
          const record = getRecordByDate(records, day.date)
          const dayEntries = entries.filter((entry) => entry.date === day.date)
          const dayIncome =
            Math.round(
              dayEntries
                .filter((entry) => entry.type === 'income')
                .reduce((sum, entry) => sum + entry.amount, 0) * 100,
            ) / 100
          const dayExpense =
            Math.round(
              dayEntries
                .filter((entry) => entry.type === 'expense')
                .reduce((sum, entry) => sum + entry.amount, 0) * 100,
            ) / 100
          const linkedCount = entries.filter(
            (entry) => entry.workDate === day.date,
          ).length
          const hasAmount = dayIncome > 0 || dayExpense > 0
          return (
            <button
              type="button"
              key={day.date}
              className={`day-row${day.isToday ? ' today' : ''}${record && record.hours > 0 ? ' has-record' : ''}${day.weekday === 0 || day.weekday === 6 ? ' weekend' : ''}`}
              style={{ '--row-index': index } as CSSProperties}
              onClick={() => setEditingDate(day.date)}
              aria-label={`${day.day}周${weekdayName(day.weekday)} ${record ? `${formatHours(record.hours)}小时` : '未记录'}${hasAmount ? ` 收支${formatMoney(dayIncome - dayExpense)}元` : ''}`}
            >
              <span className="day-date-block">
                <span className={`day-number${day.isToday ? ' today' : ''}${record && record.hours > 0 ? ' recorded' : ''}`}>
                  {day.day}
                </span>
                <span className="weekday">周{weekdayName(day.weekday)}</span>
              </span>
              <span className="day-detail">
                <span className="day-primary">
                  {record ? (
                    <span className="hours-badge">
                      {formatHours(record.hours)}
                      <small>小时</small>
                    </span>
                  ) : (
                    <span className="empty">未记录</span>
                  )}
                  {record && record.rate ? (
                    <span className={`day-amount wage${record.settled ? ' settled' : ''}`}>
                      {record.settled ? '结' : '工'} ¥{formatMoney(record.hours * (record.rate ?? 0))}
                    </span>
                  ) : null}
                  {dayIncome > 0 ? (
                    <span className="day-amount income">收入 ¥{formatMoney(dayIncome)}</span>
                  ) : null}
                  {dayExpense > 0 ? (
                    <span className="day-amount expense">支出 ¥{formatMoney(dayExpense)}</span>
                  ) : null}
                </span>
                <span className="day-secondary">
                  {record?.remark ? <span className="remark">{record.remark}</span> : null}
                  {record && record.rate && record.settled ? <span className="settled-tag">已结算</span> : null}
                  {linkedCount > 0 ? <span className="linked-ledger">{linkedCount}笔账</span> : null}
                  {!record?.remark && linkedCount === 0 ? <span className="day-hint">点击记录</span> : null}
                </span>
              </span>
              <ChevronRight className="day-chevron" size={18} aria-hidden="true" />
            </button>
          )
        })}
      </section>

      {undoRecord ? (
        <div className="undo-bar" role="status">
          <span>已删除这天的记录</span>
          <button type="button" className="button" onClick={restoreDeleted}>
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

      {exportMenuOpen ? (
        <div className="sheet-backdrop" onClick={() => setExportMenuOpen(false)}>
          <section
            className="action-sheet"
            role="dialog"
            aria-modal="true"
            aria-label="导出工时表"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="sheet-header">
              <h2>导出工时表</h2>
              <button
                type="button"
                className="icon-button"
                onClick={() => setExportMenuOpen(false)}
                aria-label="关闭"
              >
                <X size={20} />
              </button>
            </div>
            <p className="field-note">{formatMonthLabel(yearMonth)} 的工时明细，选择导出格式。</p>
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

      {editingDate ? (
        <DayEditor
          date={editingDate}
          record={getRecordByDate(records, editingDate)}
          onClose={closeEditor}
          onSaved={() => setSavedMessage('已保存')}
          onDeleted={(record, linkedIncome) => {
            setUndoRecord(record)
            setUndoLinkedIncome(linkedIncome ?? null)
          }}
          onPreviousDay={(current) => {
            const next = shiftDate(current, -1)
            setEditingDate(next)
            setYearMonth(next.slice(0, 7))
          }}
          onNextDay={(current) => {
            const next = shiftDate(current, 1)
            setEditingDate(next)
            setYearMonth(next.slice(0, 7))
          }}
        />
      ) : null}
    </div>
  )
}
