import type { BudgetTargets, WorkProfile, WorkDayRecord } from './types'

export const DEFAULT_WORK_ID = 'work-default'
export const DEFAULT_WORK_NAME = '默认工作'
export const MAX_WORK_NAME_LENGTH = 20
export const MAX_HOURLY_RATE = 99999.99

const RATE_RE = /^(?:\d{1,5}(?:\.\d{1,2})?|\.\d{1,2})$/

export type RateInputResult = { ok: true; rate: number } | { ok: false; error: string }

/** 校验并规整时薪输入（0 表示未设置） */
export function parseRateInput(raw: string): RateInputResult {
  const trimmed = raw.trim()
  if (!trimmed) return { ok: true, rate: 0 }
  if (!RATE_RE.test(trimmed)) {
    return { ok: false, error: '时薪最多两位小数' }
  }
  const rate = Number(trimmed)
  if (!Number.isFinite(rate) || rate < 0 || rate > MAX_HOURLY_RATE) {
    return { ok: false, error: '时薪需在 0 到 99999.99 之间' }
  }
  return { ok: true, rate: Math.round(rate * 100) / 100 }
}

export function formatRate(rate: number): string {
  return String(Math.round(rate * 100) / 100)
}

export function createWorkProfileId(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) {
    return `work-${crypto.randomUUID()}`
  }
  return `work-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
}

export function createDefaultWorkProfile(rate = 0): WorkProfile {
  return { id: DEFAULT_WORK_ID, name: DEFAULT_WORK_NAME, hourlyRate: rate }
}

export function normalizeWorkProfile(raw: unknown): WorkProfile | null {
  if (!raw || typeof raw !== 'object') return null
  const candidate = raw as Record<string, unknown>
  if (typeof candidate.id !== 'string' || !candidate.id.trim()) return null
  if (typeof candidate.name !== 'string' || !candidate.name.trim()) return null
  const name = candidate.name.trim().slice(0, MAX_WORK_NAME_LENGTH)
  const rate = Number(candidate.hourlyRate)
  if (
    !Number.isFinite(rate) ||
    rate < 0 ||
    rate > MAX_HOURLY_RATE ||
    Math.abs(Math.round(rate * 100) / 100 - rate) > 1e-8
  ) {
    return null
  }
  return { id: candidate.id, name, hourlyRate: Math.round(rate * 100) / 100 }
}

export function normalizeWorkProfiles(raw: unknown): WorkProfile[] {
  if (!Array.isArray(raw)) return []
  return raw
    .map(normalizeWorkProfile)
    .filter((profile): profile is WorkProfile => profile !== null)
}

export function dedupeWorkProfiles(profiles: WorkProfile[]): WorkProfile[] {
  const seen = new Set<string>()
  const result: WorkProfile[] = []
  for (const profile of profiles) {
    if (seen.has(profile.id)) continue
    seen.add(profile.id)
    result.push(profile)
  }
  return result
}

/** 确保默认工作存在且位于列表首位（默认工作固定 id=work-default） */
export function ensureDefaultWorkProfile(
  profiles: WorkProfile[],
  rate = 0,
): WorkProfile[] {
  const deduped = dedupeWorkProfiles(profiles)
  const existing = deduped.find((profile) => profile.id === DEFAULT_WORK_ID)
  if (existing) {
    return deduped.sort((a, b) =>
      a.id === DEFAULT_WORK_ID ? -1 : b.id === DEFAULT_WORK_ID ? 1 : 0,
    )
  }
  return [createDefaultWorkProfile(rate), ...deduped]
}

export function getWorkById(
  profiles: WorkProfile[],
  workId: string | undefined,
): WorkProfile | null {
  if (!workId) return null
  return profiles.find((profile) => profile.id === workId) ?? null
}

/** 记录的实际单价：优先记录快照，其次当前工作时薪，最后 0 */
export function getRecordRate(record: WorkDayRecord): number {
  if (record.rate !== undefined && Number.isFinite(record.rate)) {
    return Math.max(0, record.rate)
  }
  return 0
}

export function getRecordPay(record: WorkDayRecord): number {
  return Math.round(record.hours * getRecordRate(record) * 100) / 100
}

export const DEFAULT_BUDGET_TARGETS: BudgetTargets = {
  monthlyExpenseBudget: 0,
  monthlyIncomeGoal: 0,
}

export function normalizeBudgetTargets(raw: unknown): BudgetTargets {
  if (!raw || typeof raw !== 'object') return { ...DEFAULT_BUDGET_TARGETS }
  const candidate = raw as Record<string, unknown>
  const clean = (value: unknown): number => {
    const num = Number(value)
    if (!Number.isFinite(num) || num < 0 || num > 999999999.99) return 0
    return Math.round(num * 100) / 100
  }
  return {
    monthlyExpenseBudget: clean(candidate.monthlyExpenseBudget),
    monthlyIncomeGoal: clean(candidate.monthlyIncomeGoal),
  }
}

export const MAX_BUDGET_AMOUNT = 999999999.99

export type BudgetInputResult = { ok: true; amount: number } | { ok: false; error: string }

/** 校验预算/目标金额输入；空串视为 0（不设置） */
export function parseBudgetInput(raw: string): BudgetInputResult {
  const trimmed = raw.trim()
  if (!trimmed) return { ok: true, amount: 0 }
  const AMOUNT_RE = /^(?:\d{1,9}(?:\.\d{1,2})?|\.\d{1,2})$/
  if (!AMOUNT_RE.test(trimmed)) {
    return { ok: false, error: '金额最多两位小数' }
  }
  const amount = Number(trimmed)
  if (!Number.isFinite(amount) || amount <= 0 || amount > MAX_BUDGET_AMOUNT) {
    return { ok: false, error: '金额不能为 0 或过大' }
  }
  return { ok: true, amount: Math.round(amount * 100) / 100 }
}
