import { DEFAULT_WORK_ID, MAX_HOURLY_RATE } from './profiles'
import type { MonthSummary, WorkDayRecord, WorkProfile } from './types'

export const MAX_REMARK_LENGTH = 200
export const MAX_FIXED_PAY = 999999999.99

const HOURS_RE = /^(?:\d{1,2}(?:\.\d{1,2})?|\.\d{1,2})$/
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/

/** 元/工时转百分位定点整数，半值按远离零方向。 */
export function toScaledCents(value: number): number {
  const sign = value >= 0 ? 1 : -1
  return sign * Math.round((Math.abs(value) + 1e-9) * 100)
}

export function roundMoney(value: number): number {
  return toScaledCents(value) / 100
}

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
  return { ok: true, hours: roundMoney(hours) }
}

export function formatHours(hours: number): string {
  const rounded = roundMoney(hours)
  return String(rounded)
}

export function normalizeRecord(raw: unknown): WorkDayRecord | null {
  if (!raw || typeof raw !== 'object') return null
  const candidate = raw as Record<string, unknown>
  if (typeof candidate.date !== 'string' || !DATE_RE.test(candidate.date)) return null
  const hours = Number(candidate.hours)
  if (!Number.isFinite(hours) || hours < 0 || hours > 24) return null
  if (Math.abs(roundMoney(hours) - hours) > 1e-8) return null
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
    Math.abs(roundMoney(rate) - rate) < 1e-8
  const settled = candidate.settled === true
  const fixedPay = Number(candidate.fixedPay)
  const hasFixedPay =
    candidate.fixedPay !== undefined &&
    Number.isFinite(fixedPay) &&
    fixedPay >= 0 &&
    fixedPay <= MAX_FIXED_PAY &&
    Math.abs(roundMoney(fixedPay) - fixedPay) < 1e-8
  const record: WorkDayRecord = {
    date: candidate.date,
    hours: roundMoney(hours),
    remark,
  }
  if (workId) record.workId = workId
  if (hasRate) record.rate = roundMoney(rate)
  if (hasFixedPay) record.fixedPay = roundMoney(fixedPay)
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
  const prefix = yearMonth + '-'
  const monthRecords: WorkDayRecord[] = []
  for (const record of records) {
    if (record.date.startsWith(prefix)) monthRecords.push(record)
  }
  return monthRecords
}

/** 记录的实际单价：优先记录快照，其次当前工作时薪（旧数据无快照时也能算出工资） */
function recordRate(
  record: Pick<WorkDayRecord, 'rate' | 'workId'>,
  workProfiles?: WorkProfile[],
): number {
  if (record.rate !== undefined && Number.isFinite(record.rate) && record.rate > 0) {
    return record.rate
  }
  if (workProfiles) {
    const workId = record.workId ?? DEFAULT_WORK_ID
    const work = workProfiles.find((profile) => profile.id === workId)
    if (work && work.hourlyRate > 0) return work.hourlyRate
  }
  return 0
}

/** 记录的实际工资：固定日薪优先，其次工时 × 有效时薪。 */
function recordPay(
  record: WorkDayRecord,
  workProfiles?: WorkProfile[],
): number {
  if (
    record.fixedPay !== undefined &&
    Number.isFinite(record.fixedPay) &&
    record.fixedPay > 0
  ) {
    return roundMoney(record.fixedPay)
  }
  const scaledHours = toScaledCents(record.hours)
  const scaledRate = toScaledCents(recordRate(record, workProfiles))
  return Math.round((scaledHours * scaledRate) / 100 + 1e-9) / 100
}

/** 是否使用了自定义固定日薪。 */
export function hasFixedPay(record: Pick<WorkDayRecord, 'fixedPay'>): boolean {
  return record.fixedPay !== undefined && Number.isFinite(record.fixedPay) && record.fixedPay > 0
}

/** 公开口径：有效时薪（快照优先 → 回退当前工作时薪）。统计、结算入账、界面显示共用 */
export function getEffectiveRate(
  record: Pick<WorkDayRecord, 'rate' | 'workId'>,
  workProfiles?: WorkProfile[],
): number {
  return recordRate(record, workProfiles)
}

/** 公开口径：记录工资（hours × 有效时薪，两位小数） */
export function getRecordPay(record: WorkDayRecord, workProfiles?: WorkProfile[]): number {
  return recordPay(record, workProfiles)
}

/** 每月工资汇总（按记录时薪快照计算；旧数据无快照时回退当前工作时薪） */
export function getMonthPay(
  records: WorkDayRecord[],
  yearMonth: string,
  workProfiles?: WorkProfile[],
): number {
  const monthRecords = getMonthRecords(records, yearMonth)
  const totalCents = monthRecords.reduce(
    (sum, record) => sum + toScaledCents(getRecordPay(record, workProfiles)),
    0,
  )
  return totalCents / 100
}

/** 待结算/已结算金额（按记录时薪快照计算；旧数据无快照时回退当前工作时薪） */
export function getSettlementSummary(
  records: WorkDayRecord[],
  yearMonth: string,
  workProfiles?: WorkProfile[],
): { total: number; settled: number; pending: number; settledCount: number; pendingCount: number } {
  const monthRecords = getMonthRecords(records, yearMonth)
  let totalCents = 0
  let settledCents = 0
  let settledCount = 0
  let pendingCount = 0
  for (const record of monthRecords) {
    const pay = getRecordPay(record, workProfiles)
    if (pay <= 0) continue
    const cents = toScaledCents(pay)
    totalCents += cents
    if (record.settled) {
      settledCents += cents
      settledCount += 1
    } else {
      pendingCount += 1
    }
  }
  return {
    total: totalCents / 100,
    settled: settledCents / 100,
    pending: (totalCents - settledCents) / 100,
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
    roundMoney(
      monthRecords.reduce((total, record) => total + record.hours, 0),
    )
  const workDays = monthRecords.filter((record) => record.hours > 0).length
  const averageHours =
    workDays > 0 ? roundMoney(totalHours / workDays) : 0
  return { totalHours, workDays, averageHours }
}

/** 环比上月：返回变化量（正=增加）与百分比，上月无记录时返回 null */
export function getMonthDelta(
  records: WorkDayRecord[],
  yearMonth: string,
  shiftMonthKey: (key: string, delta: number) => string,
): { delta: number; percent: number } | null {
  const lastMonth = shiftMonthKey(yearMonth, -1)
  const current = getMonthSummary(records, yearMonth).totalHours
  const previous = getMonthSummary(records, lastMonth).totalHours
  if (previous === 0) return null
  const delta = roundMoney(current - previous)
  const percent =
    Math.round((delta / previous) * 1000) / 10
  return { delta, percent }
}
