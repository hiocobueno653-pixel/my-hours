import { ChevronLeft, ChevronRight, PenLine } from 'lucide-react'
import { useMemo, useState } from 'react'
import {
  currentMonthKey,
  formatDateLabel,
  formatMonthLabel,
  getMonthDates,
  shiftMonth,
  todayISO,
  weekdayName,
} from '../data/dates'
import { formatMoney, getLedgerMonthSummary } from '../data/ledger'
import {
  formatHours,
  getMonthSummary,
  getRecordByDate,
} from '../data/records'
import { useAppStore } from '../store/useAppStore'

interface OverviewViewProps {
  yearMonth: string
  onYearMonthChange: (yearMonth: string) => void
  onOpenDay: (date: string) => void
  embedded?: boolean
}

export function OverviewView({
  yearMonth,
  onYearMonthChange,
  onOpenDay,
  embedded = false,
}: OverviewViewProps) {
  const records = useAppStore((state) => state.records)
  const entries = useAppStore((state) => state.entries)
  const today = todayISO()
  const dates = useMemo(() => getMonthDates(yearMonth), [yearMonth])
  const [selectedDate, setSelectedDate] = useState<string | null>(null)
  const activeDate = useMemo(() => {
    if (selectedDate && selectedDate.startsWith(`${yearMonth}-`)) {
      return selectedDate
    }
    return dates.some((day) => day.date === today) ? today : dates[0]?.date ?? ''
  }, [dates, selectedDate, today, yearMonth])
  const activeRecord = activeDate ? getRecordByDate(records, activeDate) : undefined
  const activeEntries = activeDate
    ? entries.filter((entry) => entry.date === activeDate)
    : []
  const activeIncome =
    Math.round(
      activeEntries
        .filter((entry) => entry.type === 'income')
        .reduce((sum, entry) => sum + entry.amount, 0) * 100,
    ) / 100
  const activeExpense =
    Math.round(
      activeEntries
        .filter((entry) => entry.type === 'expense')
        .reduce((sum, entry) => sum + entry.amount, 0) * 100,
    ) / 100
  const summary = useMemo(
    () => getMonthSummary(records, yearMonth),
    [records, yearMonth],
  )
  const ledgerSummary = useMemo(
    () => getLedgerMonthSummary(entries, yearMonth),
    [entries, yearMonth],
  )
  const categoryRows = useMemo(() => {
    const totals = new Map<string, { name: string; type: 'income' | 'expense'; total: number }>()
    for (const entry of entries) {
      if (!entry.date.startsWith(`${yearMonth}-`)) continue
      const key = `${entry.type}:${entry.category}`
      const current = totals.get(key)
      totals.set(key, {
        name: entry.category,
        type: entry.type,
        total: Math.round(((current?.total ?? 0) + entry.amount) * 100) / 100,
      })
    }
    return Array.from(totals.values()).sort((a, b) => b.total - a.total)
  }, [entries, yearMonth])
  const incomeRows = categoryRows
    .filter((row) => row.type === 'income')
    .slice(0, 3)
  const expenseRows = categoryRows
    .filter((row) => row.type === 'expense')
    .slice(0, 3)

  return (
    <div className="overview-view">
      <header className="month-switcher">
        <button
          type="button"
          className="icon-button"
          onClick={() => onYearMonthChange(shiftMonth(yearMonth, -1))}
          aria-label="上个月"
        >
          <ChevronLeft size={22} />
        </button>
        <h2 className="month-switcher-label">{formatMonthLabel(yearMonth)}</h2>
        <button
          type="button"
          className="icon-button"
          onClick={() => onYearMonthChange(shiftMonth(yearMonth, 1))}
          aria-label="下个月"
        >
          <ChevronRight size={22} />
        </button>
      </header>

      <section className={`overview-panel${embedded ? ' overview-panel-embedded' : ''}`} aria-label="本月概览">
        <div className="overview-head">
          {embedded ? <span className="overview-context">月份日历</span> : <h2>本月概览</h2>}
          <button
            type="button"
            className="button overview-backup"
            onClick={() => onYearMonthChange(currentMonthKey())}
            aria-label="回到本月"
          >
            本月
          </button>
        </div>
        <div className="overview-stats">
          <div className="overview-stat">
            <span>月工时</span>
            <strong>{formatHours(summary.totalHours)}</strong>
          </div>
          <div className="overview-stat income">
            <span>收入</span>
            <strong>¥{formatMoney(ledgerSummary.income)}</strong>
          </div>
          <div className="overview-stat expense">
            <span>支出</span>
            <strong>¥{formatMoney(ledgerSummary.expense)}</strong>
          </div>
          <div className={`overview-stat balance${ledgerSummary.balance < 0 ? ' negative' : ''}`}>
            <span>结余</span>
            <strong>
              {ledgerSummary.balance < 0 ? '-' : ''}¥{formatMoney(Math.abs(ledgerSummary.balance))}
            </strong>
          </div>
          <div className="overview-stat">
            <span>工作天数</span>
            <strong>{summary.workDays}</strong>
          </div>
          <div className="overview-stat">
            <span>日均</span>
            <strong>{formatHours(summary.averageHours)}</strong>
          </div>
        </div>
        <div className="calendar-weekdays">
          {['日', '一', '二', '三', '四', '五', '六'].map((day) => (
            <span key={day}>{day}</span>
          ))}
        </div>
        <div className="overview-calendar">
          {dates.map((day) => {
            const record = getRecordByDate(records, day.date)
            const hasIncome = entries.some(
              (entry) => entry.date === day.date && entry.type === 'income',
            )
            const hasExpense = entries.some(
              (entry) => entry.date === day.date && entry.type === 'expense',
            )
            const classes = [
              'calendar-day',
              record && record.hours > 0 ? 'has-hours' : '',
              hasIncome ? 'has-income' : '',
              hasExpense ? 'has-expense' : '',
              day.date === activeDate ? 'selected' : '',
              day.date === today ? 'today' : '',
            ]
              .filter(Boolean)
              .join(' ')
            return (
              <button
                type="button"
                key={day.date}
                className={classes}
                onClick={() => setSelectedDate(day.date)}
                aria-pressed={day.date === activeDate}
                aria-label={`${day.date}${record ? ` ${formatHours(record.hours)}小时` : ''}`}
              >
                <span className="calendar-day-number">{day.day}</span>
                <span className="calendar-dots">
                  {record && record.hours > 0 ? <span className="dot hours" /> : null}
                  {hasIncome ? <span className="dot income" /> : null}
                  {hasExpense ? <span className="dot expense" /> : null}
                </span>
              </button>
            )
          })}
        </div>
        <div className="overview-legend">
          <span className="legend-item">
            <span className="dot hours" />
            工时
          </span>
          <span className="legend-item">
            <span className="dot income" />
            收入
          </span>
          <span className="legend-item">
            <span className="dot expense" />
            支出
          </span>
        </div>
        {activeDate ? (
          <section
            key={activeDate}
            className="overview-day-detail"
            aria-label={`${formatDateLabel(activeDate)}详情`}
          >
            <div className="overview-day-head">
              <div className="overview-day-title">
                <span>{activeDate === today ? '今天' : formatDateLabel(activeDate)}</span>
                <strong>
                  {formatDateLabel(activeDate)} · 周
                  {weekdayName(new Date(`${activeDate}T00:00:00`).getDay())}
                </strong>
              </div>
              <button
                type="button"
                className="button overview-day-edit"
                onClick={() => onOpenDay(activeDate)}
              >
                <PenLine size={16} />
                {activeRecord ? '修改记录' : '记工时'}
              </button>
            </div>
            <div className="overview-day-stats">
              <div className="overview-day-stat">
                <span>工时</span>
                <strong>{activeRecord ? formatHours(activeRecord.hours) : '--'}</strong>
                <small>小时</small>
              </div>
              <div className="overview-day-stat income">
                <span>收入</span>
                <strong>{activeIncome > 0 ? `¥${formatMoney(activeIncome)}` : '--'}</strong>
                <small>元</small>
              </div>
              <div className="overview-day-stat expense">
                <span>支出</span>
                <strong>{activeExpense > 0 ? `¥${formatMoney(activeExpense)}` : '--'}</strong>
                <small>元</small>
              </div>
            </div>
            {activeRecord?.remark ? (
              <p className="overview-day-remark">{activeRecord.remark}</p>
            ) : null}
            {activeEntries.length > 0 ? (
              <div className="overview-day-list">
                {activeEntries.map((entry) => (
                  <div className="overview-day-row" key={entry.id}>
                    <div className="overview-day-row-main">
                      <strong>{entry.category}</strong>
                      {entry.remark ? <span>{entry.remark}</span> : null}
                    </div>
                    <span className={`overview-day-amount ${entry.type}`}>
                      {entry.type === 'income' ? '+' : '-'}¥{formatMoney(entry.amount)}
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="overview-day-empty">当天没有账目</p>
            )}
          </section>
        ) : null}
        <div className="overview-categories">
          <div className="category-block">
            <h3>收入分类</h3>
            {incomeRows.length > 0 ? (
              incomeRows.map((row) => (
                <div className="category-total-row" key={`income-${row.name}`}>
                  <span>{row.name}</span>
                  <strong>¥{formatMoney(row.total)}</strong>
                </div>
              ))
            ) : (
              <span className="overview-none">暂无收入</span>
            )}
          </div>
          <div className="category-block">
            <h3>支出分类</h3>
            {expenseRows.length > 0 ? (
              expenseRows.map((row) => (
                <div className="category-total-row" key={`expense-${row.name}`}>
                  <span>{row.name}</span>
                  <strong>¥{formatMoney(row.total)}</strong>
                </div>
              ))
            ) : (
              <span className="overview-none">暂无支出</span>
            )}
          </div>
        </div>
      </section>
    </div>
  )
}
