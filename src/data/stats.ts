import { DEFAULT_WORK_ID, getRecordRate } from './profiles'
import { getMonthRecords } from './records'
import type { LedgerEntry, WorkProfile, WorkDayRecord } from './types'

export function pad2(value: number): string {
  return String(value).padStart(2, '0')
}

export function yearMonthKey(year: number, month: number): string {
  return `${year}-${pad2(month)}`
}

/** 某年的 12 个月 key（从 1 到 12） */
export function getYearMonthKeys(year: number): string[] {
  return Array.from({ length: 12 }, (_, index) => yearMonthKey(year, index + 1))
}

export interface MonthHoursPoint {
  yearMonth: string
  hours: number
  pay: number
  workDays: number
}

/** 全年每月工时与工资（按记录时薪快照） */
export function getYearHoursTrend(
  records: WorkDayRecord[],
  year: number,
): MonthHoursPoint[] {
  return getYearMonthKeys(year).map((yearMonth) => {
    const monthRecords = getMonthRecords(records, yearMonth)
    let hours = 0
    let pay = 0
    let workDays = 0
    for (const record of monthRecords) {
      hours += record.hours
      pay += record.hours * getRecordRate(record)
      if (record.hours > 0) workDays += 1
    }
    return {
      yearMonth,
      hours: Math.round(hours * 100) / 100,
      pay: Math.round(pay * 100) / 100,
      workDays,
    }
  })
}

export interface MonthLedgerPoint {
  yearMonth: string
  income: number
  expense: number
}

/** 全年每月收支汇总 */
export function getYearLedgerTrend(
  entries: LedgerEntry[],
  year: number,
): MonthLedgerPoint[] {
  return getYearMonthKeys(year).map((yearMonth) => {
    let income = 0
    let expense = 0
    for (const entry of entries) {
      if (!entry.date.startsWith(`${yearMonth}-`)) continue
      if (entry.type === 'income') income += entry.amount
      else expense += entry.amount
    }
    return {
      yearMonth,
      income: Math.round(income * 100) / 100,
      expense: Math.round(expense * 100) / 100,
    }
  })
}

export interface CategoryTotal {
  name: string
  type: 'income' | 'expense'
  total: number
}

/** 某月收支分类汇总（按金额降序） */
export function getMonthCategoryTotals(
  entries: LedgerEntry[],
  yearMonth: string,
): CategoryTotal[] {
  const totals = new Map<string, CategoryTotal>()
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
}

export interface WorkBreakdownRow {
  workId: string
  name: string
  hours: number
  pay: number
}

/** 某月按工作分组的工时与工资（含默认工作） */
export function getMonthWorkBreakdown(
  records: WorkDayRecord[],
  workProfiles: WorkProfile[],
  yearMonth: string,
): WorkBreakdownRow[] {
  const rows = new Map<string, WorkBreakdownRow>()
  const collect = (record: WorkDayRecord) => {
    const workId = record.workId ?? DEFAULT_WORK_ID
    const profile = workProfiles.find((item) => item.id === workId)
    const name = profile ? profile.name : workId === DEFAULT_WORK_ID ? '默认工作' : '未知工作'
    const existing = rows.get(workId) ?? {
      workId,
      name,
      hours: 0,
      pay: 0,
    }
    existing.hours = Math.round((existing.hours + record.hours) * 100) / 100
    existing.pay =
      Math.round((existing.pay + record.hours * getRecordRate(record)) * 100) / 100
    rows.set(workId, existing)
  }
  for (const record of getMonthRecords(records, yearMonth)) {
    if (record.hours > 0) collect(record)
  }
  const order = workProfiles.map((profile) => profile.id)
  const sorted = Array.from(rows.values()).sort((a, b) => {
    const ai = order.indexOf(a.workId)
    const bi = order.indexOf(b.workId)
    if (ai === -1 && bi === -1) return b.pay - a.pay
    if (ai === -1) return 1
    if (bi === -1) return -1
    return ai - bi
  })
  return sorted
}

/** 年度汇总：总工时、总工资、收支净额 */
export function getYearSummary(
  records: WorkDayRecord[],
  entries: LedgerEntry[],
  year: number,
): { totalHours: number; totalPay: number; totalIncome: number; totalExpense: number } {
  const prefix = `${year}-`
  let totalHours = 0
  let totalPay = 0
  let totalIncome = 0
  let totalExpense = 0
  for (const record of records) {
    if (!record.date.startsWith(prefix)) continue
    totalHours += record.hours
    totalPay += record.hours * getRecordRate(record)
  }
  for (const entry of entries) {
    if (!entry.date.startsWith(prefix)) continue
    if (entry.type === 'income') totalIncome += entry.amount
    else totalExpense += entry.amount
  }
  const round = (value: number) => Math.round(value * 100) / 100
  return {
    totalHours: round(totalHours),
    totalPay: round(totalPay),
    totalIncome: round(totalIncome),
    totalExpense: round(totalExpense),
  }
}
