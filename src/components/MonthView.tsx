import { CalendarDays, ChevronLeft, ChevronRight, Download, FileDown, FileSpreadsheet, PenLine, WalletCards } from 'lucide-react'
import { useEffect, useMemo, useRef, useState, type CSSProperties } from 'react'
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
  getMonthDelta,
  getMonthSummary,
  getRecordByDate,
  getSettlementSummary,
} from '../data/records'
import { getMonthActivities, type DayActivity } from '../data/activity'
import { exportMonthCsv, exportMonthExcel } from '../services/exportService'
import type { LedgerEntry, WorkDayRecord } from '../data/types'
import { useAppStore } from '../store/useAppStore'
import { haptic } from '../utils/haptics'
import { DayDetail } from './DayDetail'
import { DayEditor } from './DayEditor'
import { MonthDetail } from './MonthDetail'
import { MonthPicker } from './MonthPicker'
import { useModalLayer } from '../navigation/backNavigation'

// 「只记工时」变体（VITE_HOURS_ONLY=1 构建）：隐藏记账入口与账目读数
const HOURS_ONLY = import.meta.env.VITE_HOURS_ONLY === '1'

interface MonthViewProps {
  initialEditingDate?: string | null
  onEditorClosed?: () => void
  onOpenLedger?: (date: string) => void
}

type CalendarCell =
  | { key: string; blank: true }
  | { blank: false; date: string; day: number; weekday: number; isToday: boolean }

export function MonthView({
  initialEditingDate,
  onEditorClosed,
  onOpenLedger,
}: MonthViewProps = {}) {
  const records = useAppStore((state) => state.records)
  const entries = useAppStore((state) => state.entries)
  const workProfiles = useAppStore((state) => state.workProfiles)
  const [yearMonth, setYearMonth] = useState(currentMonthKey)
  const [editingDate, setEditingDate] = useState<string | null>(initialEditingDate ?? null)
  const [viewingDate, setViewingDate] = useState<string | null>(null)
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
  const [monthPickerOpen, setMonthPickerOpen] = useState(false)
  const [detailOpen, setDetailOpen] = useState(false)
  const [exitingDate, setExitingDate] = useState<string | null>(null)
  const [slideDir, setSlideDir] = useState<'left' | 'right' | null>(null)
  const touchStartRef = useRef<{ x: number; y: number } | null>(null)
  const swipedRef = useRef(false)
  const exportModal = useModalLayer(() => setExportMenuOpen(false), exportMenuOpen)
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
      setExitingDate(null)
    }, 6000)
    return () => window.clearTimeout(timer)
  }, [undoRecord])

  const dates = useMemo(() => getMonthDates(yearMonth), [yearMonth])
  const dayActivities = useMemo<DayActivity[]>(
    () => getMonthActivities(yearMonth, records, entries),
    [yearMonth, entries, records],
  )
  const activityByDate = useMemo(
    () => new Map(dayActivities.map((activity) => [activity.date, activity])),
    [dayActivities],
  )
  const calendarDays = useMemo<CalendarCell[]>(() => {
    const firstWeekday = new Date(`${yearMonth}-01T00:00:00`).getDay()
    const leading = firstWeekday === 0 ? 6 : firstWeekday - 1
    return [
      ...Array.from({ length: leading }, (_, index) => ({ key: `blank-${index}`, blank: true as const })),
      ...dates.map((day) => ({ ...day, blank: false as const })),
    ]
  }, [dates, yearMonth])
  const summary = useMemo(
    () => getMonthSummary(records, yearMonth),
    [records, yearMonth],
  )
  const settlement = useMemo(
    () => getSettlementSummary(records, yearMonth, workProfiles),
    [records, yearMonth, workProfiles],
  )
  const monthDelta = useMemo(
    () => getMonthDelta(records, yearMonth, shiftMonth),
    [records, yearMonth],
  )
  // 当前月复用月活动聚合；切到其他月份时再回退整表查询
  const todayActivity = activityByDate.get(today)
  const todayRecord = todayActivity?.record ?? getRecordByDate(records, today)
  const todayEntries =
    todayActivity?.dayEntries ?? entries.filter((entry) => entry.date === today)
  const todayIncome =
    todayActivity?.dayIncome ??
    Math.round(
      todayEntries
        .filter((entry) => entry.type === 'income')
        .reduce((sum, entry) => sum + entry.amount, 0) * 100,
    ) / 100
  const todayExpense =
    todayActivity?.dayExpense ??
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
      {
        workId: undoRecord.workId,
        rate: undoRecord.rate,
          settled: undoRecord.settled,
          fixedPay: undoRecord.fixedPay,
        },
      )
    if (undoLinkedIncome) {
      useAppStore.getState().saveLedgerEntry(undoLinkedIncome)
    }
    setUndoRecord(null)
    setUndoLinkedIncome(null)
    setExitingDate(null)
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
    <div className={`month-view page-enter${HOURS_ONLY ? ' hours-only' : ''}`}>
      <header className="work-page-header">
        <div className="work-heading-row">
          <div className="screen-header-copy">
            <span className="screen-kicker">工作记录</span>
            <h1>记工</h1>
          </div>
          <div className="header-tool-group">
            <div className="inline-month-nav" aria-label="月份切换">
              <button
                type="button"
                className="month-nav-button"
                onClick={() => {
                  setSlideDir('right')
                  setYearMonth((current) => shiftMonth(current, -1))
                }}
                aria-label="上个月"
              >
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
              <button
                type="button"
                className="month-nav-button"
                onClick={() => {
                  setSlideDir('left')
                  setYearMonth((current) => shiftMonth(current, 1))
                }}
                aria-label="下个月"
              >
                <ChevronRight size={19} />
              </button>
            </div>
            <button
              type="button"
              className="icon-button quiet"
              onClick={() => setExportMenuOpen(true)}
              aria-label="导出工时表"
              title="导出工时表"
            >
              <Download size={19} />
            </button>
          </div>
        </div>
      </header>

      <section className="work-overview" aria-label="月总计">
        <div className="work-overview-primary">
          <span>本月总工时</span>
          <div className="work-overview-number">
            <strong>{formatHours(summary.totalHours)}</strong>
            <small>小时</small>
          </div>
          {monthDelta ? (
            <span className={`hero-delta${monthDelta.delta >= 0 ? ' up' : ' down'}`}>
              {monthDelta.delta >= 0 ? '↑' : '↓'} 比上月 {monthDelta.delta >= 0 ? '+' : ''}{formatHours(monthDelta.delta)} 小时（{monthDelta.delta >= 0 ? '+' : ''}{monthDelta.percent}%）
            </span>
          ) : null}
        </div>
        <div className="work-overview-details hours-only-layout">
          {HOURS_ONLY ? null : (
          <div className="work-overview-pay">
            <span>待结算</span>
            <strong>¥{formatMoney(settlement.pending)}</strong>
            {settlement.total > 0 ? (
              <small>已结算 ¥{formatMoney(settlement.settled)}</small>
            ) : summary.workDays > 0 ? (
              <small className="setup-wage-hint">未设时薪 · 去我的页设置</small>
            ) : (
              <small>未设时薪</small>
            )}
          </div>
          )}
          <dl className="work-overview-stats">
            <div>
              <dt>工作日</dt>
              <dd>{summary.workDays}<small> 天</small></dd>
            </div>
            <div>
              <dt>日均</dt>
              <dd>{formatHours(summary.averageHours)}<small> 小时</small></dd>
            </div>
          </dl>
        </div>
      </section>

      {!isCurrentMonth ? (
        <button type="button" className="back-to-now" onClick={() => setYearMonth(currentMonthKey())}>
          <CalendarDays size={14} />
          回到本月
        </button>
      ) : null}

      {isCurrentMonth ? (
        <section className="today-workspace" aria-label="今天">
          <div className="today-workspace-main">
            <div className="today-workspace-copy">
              <span>今天 · 周{weekdayName(new Date(`${today}T00:00:00`).getDay())}</span>
              <strong>{formatDateLabel(today)}</strong>
              <p>{todayRecord?.remark || (!todayRecord && todayEntries.length === 0 ? '今天还没有记录' : HOURS_ONLY ? '今天的工作' : '今天的工作与账目')}</p>
            </div>
            <div className="today-workspace-actions">
              {onOpenLedger ? (
              <button
                type="button"
                className="today-ledger-button"
                onClick={() => onOpenLedger?.(today)}
                aria-label="今天记一笔账"
                title="记一笔账"
              >
                <WalletCards size={16} />
                记一笔
              </button>
              ) : null}
              <button type="button" className="today-record-button" onClick={() => setEditingDate(today)}>
                <PenLine size={17} />
                {todayRecord ? '修改记录' : '记工时'}
              </button>
            </div>
          </div>
          <div className={`today-readout${HOURS_ONLY ? ' hours-only' : ''}`} aria-label="今天汇总">
            <div>
              <span>工时</span>
              <strong>
                {todayRecord ? (
                  <>
                    {formatHours(todayRecord.hours)}
                    <small> 小时</small>
                  </>
                ) : (
                  '--'
                )}
              </strong>
            </div>
            {HOURS_ONLY ? null : (
            <div>
              <span>收入</span>
              <strong className="income">{todayIncome > 0 ? `¥${formatMoney(todayIncome)}` : '--'}</strong>
            </div>
            )}
            {HOURS_ONLY ? null : (
            <div>
              <span>账目</span>
              <strong>
                {todayEntries.length > 0 ? (
                  <>
                    {todayEntries.length}
                    <small> 笔</small>
                  </>
                ) : (
                  '--'
                )}
              </strong>
            </div>
            )}
          </div>
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

      <section
        className={`month-calendar${slideDir ? ` slide-${slideDir}` : ''}`}
        key={yearMonth}
        onAnimationEnd={() => setSlideDir(null)}
        aria-label={isCurrentMonth ? '本月日历' : '每月日历'}
        onTouchStart={(event) => {
          const touch = event.touches[0]
          touchStartRef.current = { x: touch.clientX, y: touch.clientY }
          swipedRef.current = false
        }}
        onTouchEnd={(event) => {
          const start = touchStartRef.current
          touchStartRef.current = null
          if (!start) return
          const touch = event.changedTouches[0]
          const dx = touch.clientX - start.x
          const dy = touch.clientY - start.y
          // 横向滑动超过 50px 且横向位移大于纵向（避免误触垂直滚动）
          if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy) * 1.5) {
            swipedRef.current = true
            const next = dx < 0 ? 1 : -1
            setSlideDir(dx < 0 ? 'left' : 'right')
            setYearMonth((current) => shiftMonth(current, next))
          }
        }}
      >
        <div className="day-list-heading">
          <span>{isCurrentMonth ? '本月日历' : '每日记录'}</span>
          <small>{dates.length}天 · 点击日期记录</small>
        </div>
        <div className="calendar-week-labels" aria-hidden="true">
          {['一', '二', '三', '四', '五', '六', '日'].map((label) => (
            <span key={label}>{label}</span>
          ))}
        </div>
        <div className="calendar-grid">
          {calendarDays.map((item, index) => {
            if (item.blank) {
              return <span key={item.key} className="calendar-blank" aria-hidden="true" />
            }

            const day = item
            const activity = activityByDate.get(day.date)
            const record = activity?.record
            const dayIncome = activity?.dayIncome ?? 0
            const dayExpense = activity?.dayExpense ?? 0
            const linkedCount = activity?.linkedCount ?? 0
            const hasAmount = dayIncome > 0 || dayExpense > 0
            const isFuture = day.date > today
            const classes = [
              'calendar-day',
              day.isToday ? 'today' : '',
              record && record.hours > 0 ? 'has-record' : '',
              record && record.hours === 0 ? 'rest' : '',
              day.weekday === 0 || day.weekday === 6 ? 'weekend' : '',
              isFuture ? 'future' : '',
              record?.settled && !HOURS_ONLY ? 'settled' : '',
            ]
              .filter(Boolean)
              .join(' ')

            return (
              <button
                type="button"
                key={day.date}
                className={classes}
                style={{ '--row-index': index } as CSSProperties}
                disabled={isFuture}
                onClick={
                  isFuture
                    ? undefined
                    : () => {
                        if (swipedRef.current) {
                          swipedRef.current = false
                          return
                        }
                        if (record) {
                          setViewingDate(day.date)
                        } else {
                          setEditingDate(day.date)
                        }
                      }
                }
                aria-label={`${day.day}周${weekdayName(day.weekday)} ${
                  isFuture ? '还未到' : record ? (record.hours === 0 ? '休息' : `${formatHours(record.hours)}小时`) : '未记录'
                }${!HOURS_ONLY && record?.settled ? ' 已结算' : ''}${!HOURS_ONLY && hasAmount ? ` 收支${formatMoney(dayIncome - dayExpense)}元` : ''}${
                  !HOURS_ONLY && linkedCount > 0 ? ` ${linkedCount}笔关联账目` : ''
                }`}
              >
                <span className={`day-number${day.isToday ? " today" : ""}${record && record.hours > 0 ? " recorded" : ""}`}>
                  {day.day}
                </span>
                {record ? (
                  record.hours === 0 ? (
                    <span className="calendar-hours rest-label">休</span>
                  ) : (
                    <span className="calendar-hours">{formatHours(record.hours)}</span>
                  )
                ) : (
                  <span className="calendar-hours muted">-</span>
                )}
                <span className="calendar-dots" aria-hidden="true">
                  {!HOURS_ONLY && record?.settled ? <span className="calendar-dot settled-dot" /> : null}
                  {!HOURS_ONLY && dayIncome > 0 ? <span className="calendar-dot income-dot" /> : null}
                  {!HOURS_ONLY && dayExpense > 0 ? <span className="calendar-dot expense-dot" /> : null}
                </span>
              </button>
            )
          })}
        </div>
        <div className="calendar-legend" aria-hidden="true">
          <span className="legend-recorded">有工时</span>
          {HOURS_ONLY ? null : (
          <>
          <span><i className="income" />收入</span>
          <span><i className="expense" />支出</span>
          <span><i className="settled" />已结算</span>
          </>
          )}
        </div>
        <button
          type="button"
          className="month-detail-button"
          onClick={() => setDetailOpen(true)}
        >
          明细
        </button>
      </section>

      {detailOpen ? (
        <MonthDetail
          initialMonth={yearMonth}
          exitingDate={exitingDate}
          exitingRecord={undoRecord}
          onExitComplete={() => setExitingDate(null)}
          onClose={() => {
            setDetailOpen(false)
            setExitingDate(null)
          }}
          onOpenDay={(date) => {
            // 明细保持打开：有记录则打开详情（DayDetail），无记录才进编辑器
            if (getRecordByDate(records, date)) {
              setViewingDate(date)
            } else {
              setEditingDate(date)
            }
          }}
        />
      ) : null}
      {undoRecord ? (
        <div className="undo-bar top-toast" role="status">
          <span>已删除这天的记录</span>
          <button type="button" className="button" onClick={restoreDeleted}>
            撤销
          </button>
        </div>
      ) : null}
      {savedMessage ? (
        <p className="status-line save-status top-toast" role="status">
          {savedMessage}
        </p>
      ) : null}
      {exportState ? (
        <p className="status-line" role="status">
          {exportState}
        </p>
      ) : null}

      {exportMenuOpen ? (
        <div className="menu-backdrop" ref={exportModal.containerRef} onClick={() => setExportMenuOpen(false)} onKeyDown={exportModal.onKeyDown}>
          <section
            className="glass-menu"
            role="dialog"
            aria-modal="true"
            aria-label="导出工时表"
            onClick={(event) => event.stopPropagation()}
          >
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

      {viewingDate ? (
        <DayDetail
          date={viewingDate}
          record={getRecordByDate(records, viewingDate)}
          onEdit={() => {
            setEditingDate(viewingDate)
            setViewingDate(null)
          }}
          onClose={() => setViewingDate(null)}
        />
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
            setExitingDate(record.date)
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
