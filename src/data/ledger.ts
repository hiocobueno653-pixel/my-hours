import type {
  CustomLedgerCategory,
  LedgerEntry,
  LedgerMonthSummary,
  LedgerType,
} from './types'

export const MAX_LEDGER_REMARK_LENGTH = 200
export const MAX_LEDGER_AMOUNT = 999999999.99
export const MAX_CATEGORY_NAME_LENGTH = 20

export const DEFAULT_LEDGER_CATEGORIES: Record<LedgerType, readonly string[]> = {
  income: ['工资', '奖金', '兼职', '报销', '其他收入'],
  expense: ['餐饮', '交通', '购物', '居住', '医疗', '学习', '娱乐', '其他支出'],
}

const AMOUNT_RE = /^(?:\d{1,9}(?:\.\d{1,2})?|\.\d{1,2})$/
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/

export type AmountInputResult =
  | { ok: true; amount: number }
  | { ok: false; error: string }

export function parseAmountInput(raw: string): AmountInputResult {
  const trimmed = raw.trim()
  if (!trimmed) return { ok: false, error: '请填写金额' }
  if (!AMOUNT_RE.test(trimmed)) {
    return { ok: false, error: '金额最多两位小数' }
  }
  const amount = Number(trimmed)
  if (!Number.isFinite(amount) || amount <= 0 || amount > MAX_LEDGER_AMOUNT) {
    return { ok: false, error: '金额不能为 0 或过大' }
  }
  return { ok: true, amount: Math.round(amount * 100) / 100 }
}

export function normalizeLedgerEntry(raw: unknown): LedgerEntry | null {
  if (!raw || typeof raw !== 'object') return null
  const candidate = raw as Record<string, unknown>
  if (typeof candidate.id !== 'string' || !candidate.id.trim()) return null
  if (typeof candidate.date !== 'string' || !DATE_RE.test(candidate.date)) return null
  if (candidate.type !== 'income' && candidate.type !== 'expense') return null
  if (typeof candidate.category !== 'string' || !candidate.category.trim()) {
    return null
  }
  const amount = Number(candidate.amount)
  if (
    !Number.isFinite(amount) ||
    amount <= 0 ||
    amount > MAX_LEDGER_AMOUNT ||
    Math.abs(Math.round(amount * 100) / 100 - amount) > 1e-8
  ) {
    return null
  }
  const remark =
    typeof candidate.remark === 'string'
      ? candidate.remark.slice(0, MAX_LEDGER_REMARK_LENGTH)
      : ''
  const workDate =
    typeof candidate.workDate === 'string' && DATE_RE.test(candidate.workDate)
      ? candidate.workDate
      : undefined
  return {
    id: candidate.id,
    date: candidate.date,
    type: candidate.type,
    category: candidate.category,
    amount: Math.round(amount * 100) / 100,
    remark,
    ...(workDate ? { workDate } : {}),
  }
}

export function normalizeLedgerEntries(raw: unknown): LedgerEntry[] {
  if (!Array.isArray(raw)) return []
  return raw
    .map(normalizeLedgerEntry)
    .filter((entry): entry is LedgerEntry => entry !== null)
}

export function dedupeLedgerEntries(entries: LedgerEntry[]): LedgerEntry[] {
  const byId = new Map<string, LedgerEntry>()
  for (const entry of entries) byId.set(entry.id, entry)
  return sortLedgerEntries(Array.from(byId.values()))
}

export function sortLedgerEntries(entries: LedgerEntry[]): LedgerEntry[] {
  return [...entries].sort((a, b) => {
    if (a.date !== b.date) return a.date < b.date ? -1 : 1
    return a.id < b.id ? -1 : 1
  })
}

export function sortLedgerEntriesNewestFirst(
  entries: LedgerEntry[],
): LedgerEntry[] {
  return sortLedgerEntries(entries).reverse()
}

export function getLedgerMonthEntries(
  entries: LedgerEntry[],
  yearMonth: string,
): LedgerEntry[] {
  return sortLedgerEntriesNewestFirst(
    entries.filter((entry) => entry.date.startsWith(`${yearMonth}-`)),
  )
}

export function getLedgerMonthSummary(
  entries: LedgerEntry[],
  yearMonth: string,
): LedgerMonthSummary {
  let income = 0
  let expense = 0
  for (const entry of entries) {
    if (!entry.date.startsWith(`${yearMonth}-`)) continue
    if (entry.type === 'income') income += entry.amount
    else expense += entry.amount
  }
  const roundedIncome = Math.round(income * 100) / 100
  const roundedExpense = Math.round(expense * 100) / 100
  return {
    income: roundedIncome,
    expense: roundedExpense,
    balance: Math.round((roundedIncome - roundedExpense) * 100) / 100,
  }
}

export function formatMoney(amount: number): string {
  const rounded = Math.round(amount * 100) / 100
  return String(rounded)
}

export function createLedgerEntryId(): string {
  return createId('entry')
}

export function normalizeLedgerCategory(raw: unknown): CustomLedgerCategory | null {
  if (!raw || typeof raw !== 'object') return null
  const candidate = raw as Record<string, unknown>
  if (typeof candidate.id !== 'string' || !candidate.id.trim()) return null
  if (candidate.type !== 'income' && candidate.type !== 'expense') return null
  if (typeof candidate.name !== 'string' || !candidate.name.trim()) return null
  const name = candidate.name.trim().slice(0, MAX_CATEGORY_NAME_LENGTH)
  return { id: candidate.id, type: candidate.type, name }
}

export function normalizeLedgerCategories(
  raw: unknown,
): CustomLedgerCategory[] {
  if (!Array.isArray(raw)) return []
  return raw
    .map(normalizeLedgerCategory)
    .filter((category): category is CustomLedgerCategory => category !== null)
}

export function dedupeLedgerCategories(
  categories: CustomLedgerCategory[],
): CustomLedgerCategory[] {
  const seen = new Set<string>()
  const result: CustomLedgerCategory[] = []
  for (const category of categories) {
    const key = `${category.type}:${category.name}`
    if (seen.has(key)) continue
    seen.add(key)
    result.push(category)
  }
  return result
}

export function getAvailableLedgerCategories(
  type: LedgerType,
  customCategories: CustomLedgerCategory[],
  extraCategory?: string,
): string[] {
  const defaults = DEFAULT_LEDGER_CATEGORIES[type]
  const custom = customCategories
    .filter((category) => category.type === type)
    .map((category) => category.name)
  const names = [...defaults, ...custom]
  if (extraCategory && !names.includes(extraCategory)) names.push(extraCategory)
  return names
}

export function isLedgerCategoryNameAvailable(
  type: LedgerType,
  name: string,
  customCategories: CustomLedgerCategory[],
): boolean {
  const normalized = name.trim()
  if (!normalized) return false
  const existing = [
    ...DEFAULT_LEDGER_CATEGORIES[type],
    ...customCategories
      .filter((category) => category.type === type)
      .map((category) => category.name),
  ]
  return !existing.includes(normalized)
}

export function isLedgerCategoryInUse(
  entries: LedgerEntry[],
  type: LedgerType,
  name: string,
): boolean {
  return entries.some((entry) => entry.type === type && entry.category === name)
}

function createId(prefix: string): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) {
    return `${prefix}-${crypto.randomUUID()}`
  }
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
}
