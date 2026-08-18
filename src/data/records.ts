import { MAX_HOURLY_RATE } from './profiles'
import type { MonthSummary, WorkDayRecord } from './types'

export const MAX_REMARK_LENGTH = 200

const HOURS_RE = /^(?:\d{1,2}(?:\.\d{1,2})?|\.\d{1,2})$/
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/

export type HoursInputResult =
  | { ok: true; hours: number }
  | { ok: false; error: string }

export function parseHoursInput(raw: string): HoursInputResult {
  const trimmed = raw.trim()
  if (!trimmed) return { ok: false, error: '请填写工时' }
  if (!HOURS_RE.test(trimmed)) {
    return { ok: false, error: '工时最多两位小数' }
  }
  const hours = Number(trimmed)
  if (!Number.isFinite(hours) || hours < 0 || hours > 24) {
    return { ok: false, error: '工时需在 0 到 24 之间' }
  }
  return { ok: true, hours: Math.round(hours * 100) / 100 }
}

export function formatHours(hours: number): string {
  const rounded = Math.round(hours * 100) / 100
  return String(rounded)
}

export function normalizeRecord(raw: unknown): WorkDayRecord | null {
  if (!raw || typeof raw !== 'object') return null
  const candidate = raw as Record<string, unknown>
  if (typeof candidate.date !== 'string' || !DATE_RE.test(candidate.date)) return null
  const hours = Number(candidate.hours)
  if (!Number.isFinite(hours) || hours < 0 || hours > 24) return null
  if (Math.abs(Math.round(hours * 100) / 100 - hours) > 1e-8) return null
  const remark =
    typeof candidate.remark === 'string'
      ? candidate.remark.slice(0, MAX_REMARK_LENGTH)
      : ''
  const workId =
    typeof candidate.workId === 'string' && candidate.workId.trim()
      ? candidate.workId.trim()
      : undefined
  const rate = Number(candidate.rate)
  const hasRate =
    candidate.rate !== undefined &&
    Number.isFinite(rate) &&
    rate >= 0 &&
    rate <= MAX_HOURLY_RATE &&
    Math.abs(Math.round(rate * 100) / 100 - rate) < 1e-8
  const settled = candidate.settled === true
  const record: WorkDayRecord = {
    date: candidate.date,
    hours: Math.round(hours * 100) / 100,
    remark,
  }
  if (workId) record.workId = workId
  if (hasRate) record.rate = Math.round(rate * 100) / 100
  if (settled) record.settled = true
  return record
}

export function normalizeRecords(raw: unknown): WorkDayRecord[] {
  if (!Array.isArray(raw)) return []
  return raw
    .map(normalizeRecord)
    .filter((record): record is WorkDayRecord => record !== null)
}

export function sortRecords(records: WorkDayRecord[]): WorkDayRecord[] {
  return [...records].sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0))
}

export function dedupeRecords(records: WorkDayRecord[]): WorkDayRecord[] {
  const byDate = new Map<string, WorkDayRecord>()
  for (const record of records) {
    byDate.set(record.date, record)
  }
  return sortRecords(Array.from(byDate.values()))
}

export function getRecordByDate(
  records: WorkDayRecord[],
  date: string,
): WorkDayRecord | undefined {
  return records.find((record) => record.date === date)
}

export function getMonthRecords(
  records: WorkDayRecord[],
  yearMonth: string,
): WorkDayRecord[] {
  return sortRecords(
    records.filter((record) => record.date.startsWith(`${yearMonth}-`)),
  )
}

/** 每月工资汇总（按记录时薪快照计算） */
export function getMonthPay(records: WorkDayRecord[], yearMonth: string): number {
  const monthRecords = getMonthRecords(records, yearMonth)
  const total = monthRecords.reduce(
    (sum, record) => sum + (record.hours * (record.rate ?? 0)),
    0,
  )
  return Math.round(total * 100) / 100
}

/** 待结算/已结算金额（按记录时薪快照计算） */
export function getSettlementSummary(
  records: WorkDayRecord[],
  yearMonth: string,
): { total: number; settled: number; pending: number; settledCount: number; pendingCount: number } {
  const monthRecords = getMonthRecords(records, yearMonth)
  let total = 0
  let settled = 0
  let settledCount = 0
  let pendingCount = 0
  for (const record of monthRecords) {
    const pay = (record.hours * (record.rate ?? 0))
    if (pay <= 0) continue
    total += pay
    if (record.settled) {
      settled += pay
      settledCount += 1
    } else {
      pendingCount += 1
    }
  }
  const round = (value: number) => Math.round(value * 100) / 100
  return {
    total: round(total),
    settled: round(settled),
    pending: round(total - settled),
    settledCount,
    pendingCount,
  }
}

export function getMonthSummary(
  records: WorkDayRecord[],
  yearMonth: string,
): MonthSummary {
  const monthRecords = getMonthRecords(records, yearMonth)
  const totalHours =
    Math.round(
      monthRecords.reduce((total, record) => total + record.hours, 0) * 100,
    ) / 100
  const workDays = monthRecords.filter((record) => record.hours > 0).length
  const averageHours =
    workDays > 0 ? Math.round((totalHours / workDays) * 100) / 100 : 0
  return { totalHours, workDays, averageHours }
}
