import { type MonthDay, getMonthDates } from './dates'
import type { LedgerEntry, WorkDayRecord } from './types'

/** 某天活动聚合：工时记录 + 当日账目 + 收支金额 + 关联账目数 */
export interface DayActivity extends MonthDay {
  record?: WorkDayRecord
  dayEntries: LedgerEntry[]
  dayIncome: number
  dayExpense: number
  linkedCount: number
}

const round2 = (value: number) => Math.round(value * 100) / 100

/** 汇总某月每一天的活动（用于月历点标、本月明细列表等） */
export function getMonthActivities(
  month: string,
  records: WorkDayRecord[],
  entries: LedgerEntry[],
): DayActivity[] {
  const dates = getMonthDates(month)
  const recordByDate = new Map<string, WorkDayRecord>()
  const entriesByDate = new Map<string, LedgerEntry[]>()
  const linkedCountByDate = new Map<string, number>()
  for (const record of records) {
    if (!recordByDate.has(record.date)) recordByDate.set(record.date, record)
  }
  for (const entry of entries) {
    const dayEntries = entriesByDate.get(entry.date)
    if (dayEntries) {
      dayEntries.push(entry)
    } else {
      entriesByDate.set(entry.date, [entry])
    }
    if (entry.workDate) {
      linkedCountByDate.set(
        entry.workDate,
        (linkedCountByDate.get(entry.workDate) ?? 0) + 1,
      )
    }
  }
  return dates.map((day) => {
    const dayEntries = entriesByDate.get(day.date) ?? []
    let income = 0
    let expense = 0
    for (const entry of dayEntries) {
      if (entry.type === 'income') income += entry.amount
      else expense += entry.amount
    }
    return {
      ...day,
      record: recordByDate.get(day.date),
      dayEntries,
      dayIncome: round2(income),
      dayExpense: round2(expense),
      linkedCount: linkedCountByDate.get(day.date) ?? 0,
    }
  })
}

/** 仅保留有工时记录或有账目的天数，按日期倒序 */
export function getRecordedActivities(activities: DayActivity[]): DayActivity[] {
  return activities
    .filter((activity) => activity.record || activity.dayEntries.length > 0)
    .sort((left, right) => right.date.localeCompare(left.date))
}
