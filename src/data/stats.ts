import { DEFAULT_WORK_ID } from './profiles'
import { getMonthRecords, getRecordPay, roundMoney, toScaledCents } from './records'
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
  workProfiles?: WorkProfile[],
): MonthHoursPoint[] {
  const monthKeys = getYearMonthKeys(year)
  const byMonth = new Map<
    string,
    { hours: number; payCents: number; workDays: number }
  >()
  for (const yearMonth of monthKeys) {
    byMonth.set(yearMonth, { hours: 0, payCents: 0, workDays: 0 })
  }
  const yearPrefix = year + '-'
  for (const record of records) {
    if (!record.date.startsWith(yearPrefix)) continue
    const yearMonth = record.date.slice(0, 7)
    const point = byMonth.get(yearMonth)
    if (!point) continue
    point.hours += record.hours
    point.payCents += toScaledCents(getRecordPay(record, workProfiles))
    if (record.hours > 0) point.workDays += 1
  }
  return monthKeys.map((yearMonth) => {
    const point = byMonth.get(yearMonth) as {
      hours: number
      payCents: number
      workDays: number
    }
    return {
      yearMonth,
      hours: roundMoney(point.hours),
      pay: point.payCents / 100,
      workDays: point.workDays,
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
  const monthKeys = getYearMonthKeys(year)
  const byMonth = new Map<string, { incomeCents: number; expenseCents: number }>()
  for (const yearMonth of monthKeys) {
    byMonth.set(yearMonth, { incomeCents: 0, expenseCents: 0 })
  }
  const yearPrefix = year + '-'
  for (const entry of entries) {
    if (!entry.date.startsWith(yearPrefix)) continue
    const yearMonth = entry.date.slice(0, 7)
    const point = byMonth.get(yearMonth)
    if (!point) continue
    if (entry.type === 'income') {
      point.incomeCents += toScaledCents(entry.amount)
    } else {
      point.expenseCents += toScaledCents(entry.amount)
    }
  }
  return monthKeys.map((yearMonth) => {
    const point = byMonth.get(yearMonth) as {
      incomeCents: number
      expenseCents: number
    }
    return {
      yearMonth,
      income: point.incomeCents / 100,
      expense: point.expenseCents / 100,
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
      total:
        (toScaledCents(current?.total ?? 0) + toScaledCents(entry.amount)) /
        100,
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
    existing.hours = roundMoney(existing.hours + record.hours)
    existing.pay =
      (toScaledCents(existing.pay) +
        toScaledCents(getRecordPay(record, workProfiles))) /
      100
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
  workProfiles?: WorkProfile[],
): { totalHours: number; totalPay: number; totalIncome: number; totalExpense: number } {
  const prefix = `${year}-`
  let totalHours = 0
  let totalPayCents = 0
  let totalIncomeCents = 0
  let totalExpenseCents = 0
  for (const record of records) {
    if (!record.date.startsWith(prefix)) continue
    totalHours += record.hours
    totalPayCents += toScaledCents(getRecordPay(record, workProfiles))
  }
  for (const entry of entries) {
    if (!entry.date.startsWith(prefix)) continue
    if (entry.type === 'income') {
      totalIncomeCents += toScaledCents(entry.amount)
    } else {
      totalExpenseCents += toScaledCents(entry.amount)
    }
  }
  return {
    totalHours: roundMoney(totalHours),
    totalPay: totalPayCents / 100,
    totalIncome: totalIncomeCents / 100,
    totalExpense: totalExpenseCents / 100,
  }
}
