import { useMemo } from 'react'
import { formatMoney } from '../data/ledger'
import { formatHours, getRecordByDate } from '../data/records'
import { getRecordPay } from '../data/profiles'
import { shiftDate, todayISO, weekdayName } from '../data/dates'
import { useAppStore } from '../store/useAppStore'

interface WeekStripProps {
  onSelectDate: (date: string) => void
}

/**
 * 本周概览条：周一到周日圆点（已记录/今天高亮），合计工时/工资/天数。
 * 方便按周结算与补记本周记录。
 */
export function WeekStrip({ onSelectDate }: WeekStripProps) {
  const records = useAppStore((state) => state.records)
  const today = todayISO()
  const days = useMemo(() => {
    const date = new Date(`${today}T00:00:00`)
    const monday = date.getDay() === 0 ? shiftDate(today, -6) : shiftDate(today, 1 - date.getDay())
    return Array.from({ length: 7 }, (_, index) => {
      const d = shiftDate(monday, index)
      return { date: d, label: weekdayName(new Date(`${d}T00:00:00`).getDay()) }
    })
  }, [today])

  let totalHours = 0
  let totalPay = 0
  let workDays = 0
  let pendingCount = 0
  for (const day of days) {
    const record = getRecordByDate(records, day.date)
    if (!record || record.hours <= 0) continue
    totalHours += record.hours
    totalPay += getRecordPay(record)
    workDays += 1
    if (!record.settled) pendingCount += 1
  }
  totalHours = Math.round(totalHours * 100) / 100
  totalPay = Math.round(totalPay * 100) / 100

  return (
    <section className="week-strip" aria-label="本周概览">
      <div className="week-strip-head">
        <div className="week-strip-title">
          <span>本周</span>
          <strong>{formatHours(totalHours)} 小时</strong>
          <span>·</span>
          <strong className="week-pay">¥{formatMoney(totalPay)}</strong>
          <span className="week-days">{workDays} 天</span>
        </div>
        {pendingCount > 0 ? <span className="week-pending">{pendingCount} 笔待结算</span> : null}
      </div>
      <div className="week-dots">
        {days.map((day) => {
          const record = getRecordByDate(records, day.date)
          const hasRecord = Boolean(record && record.hours > 0)
          const isToday = day.date === today
          const isFuture = day.date > today
          return (
            <button
              type="button"
              key={day.date}
              className={`week-dot${hasRecord ? ' has-record' : ''}${isToday ? ' today' : ''}${isFuture ? ' future' : ''}`}
              onClick={() => onSelectDate(day.date)}
              disabled={isFuture}
              aria-label={`${day.label} ${day.date.slice(5)}${record ? `，${formatHours(record.hours)}小时` : '，未记录'}`}
            >
              <span className="week-dot-day">{day.date.slice(-2).replace(/^0/, '')}</span>
              <span className="week-dot-label">{day.label}</span>
            </button>
          )
        })}
      </div>
    </section>
  )
}
