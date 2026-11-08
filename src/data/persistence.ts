import { normalizeLedgerCategories, normalizeLedgerEntries } from './ledger'
import {
  DEFAULT_BUDGET_TARGETS,
  dedupeWorkProfiles,
  ensureDefaultWorkProfile,
  normalizeBudgetTargets,
  normalizeWorkProfiles,
} from './profiles'
import { dedupeRecords, normalizeRecords } from './records'
import type {
  BudgetTargets,
  CustomLedgerCategory,
  LedgerEntry,
  WorkDayRecord,
  WorkProfile,
} from './types'

const DATA_KEY = 'my-hours.data.v1'
const DATA_VERSION = 1
const BACKUP_KEY = `${DATA_KEY}.bak`
const OLD_BACKUP_KEY = `${DATA_KEY}.bak.1`
const LEDGER_KEY = 'my-hours.ledger.v1'
const LEDGER_BACKUP_KEY = `${LEDGER_KEY}.bak`
const LEDGER_OLD_BACKUP_KEY = `${LEDGER_KEY}.bak.1`
const CATEGORY_KEY = 'my-hours.customCategories.v1'
const CATEGORY_BACKUP_KEY = `${CATEGORY_KEY}.bak`
const CATEGORY_OLD_BACKUP_KEY = `${CATEGORY_KEY}.bak.1`
const PROFILE_KEY = 'my-hours.workProfiles.v1'
const PROFILE_BACKUP_KEY = `${PROFILE_KEY}.bak`
const PROFILE_OLD_BACKUP_KEY = `${PROFILE_KEY}.bak.1`
const BUDGET_KEY = 'my-hours.budget.v1'

interface Envelope<T> {
  __v: number
  data: T
}

type StoredData =
  | WorkDayRecord[]
  | LedgerEntry[]
  | CustomLedgerCategory[]
  | WorkProfile[]
  | BudgetTargets

function parseStored(raw: string): WorkDayRecord[] | null {
  try {
    const parsed = JSON.parse(raw) as unknown
    const data =
      parsed &&
      typeof parsed === 'object' &&
      '__v' in (parsed as Record<string, unknown>)
        ? (parsed as Envelope<unknown>).data
        : parsed
    return dedupeRecords(normalizeRecords(data))
  } catch {
    return null
  }
}

function parseLedgerStored(raw: string): LedgerEntry[] | null {
  try {
    const parsed = JSON.parse(raw) as unknown
    const data =
      parsed &&
      typeof parsed === 'object' &&
      '__v' in (parsed as Record<string, unknown>)
        ? (parsed as Envelope<unknown>).data
        : parsed
    return normalizeLedgerEntries(data)
  } catch {
    return null
  }
}

function parseCategoryStored(raw: string): CustomLedgerCategory[] | null {
  try {
    const parsed = JSON.parse(raw) as unknown
    const data =
      parsed &&
      typeof parsed === 'object' &&
      '__v' in (parsed as Record<string, unknown>)
        ? (parsed as Envelope<unknown>).data
        : parsed
    return normalizeLedgerCategories(data)
  } catch {
    return null
  }
}

function parseWorkProfileStored(raw: string): WorkProfile[] | null {
  try {
    const parsed = JSON.parse(raw) as unknown
    const data =
      parsed &&
      typeof parsed === 'object' &&
      '__v' in (parsed as Record<string, unknown>)
        ? (parsed as Envelope<unknown>).data
        : parsed
    return ensureDefaultWorkProfile(
      dedupeWorkProfiles(normalizeWorkProfiles(data)),
    )
  } catch {
    return null
  }
}

function parseBudgetStored(raw: string): BudgetTargets | null {
  try {
    const parsed = JSON.parse(raw) as unknown
    const data =
      parsed &&
      typeof parsed === 'object' &&
      '__v' in (parsed as Record<string, unknown>)
        ? (parsed as Envelope<unknown>).data
        : parsed
    return normalizeBudgetTargets(data)
  } catch {
    return null
  }
}

function readKey(
  key: string,
  parser: (raw: string) => StoredData | null,
): StoredData | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = window.localStorage.getItem(key)
    return raw ? parser(raw) : null
  } catch {
    return null
  }
}

export function loadRecords(): WorkDayRecord[] {
  const main = readKey(DATA_KEY, parseStored)
  if (main) return main as WorkDayRecord[]
  const backup = readKey(BACKUP_KEY, parseStored)
  if (backup) return backup as WorkDayRecord[]
  const oldBackup = readKey(OLD_BACKUP_KEY, parseStored)
  return (oldBackup as WorkDayRecord[] | null) ?? []
}

export function saveRecords(records: WorkDayRecord[]): void {
  if (typeof window === 'undefined') return
  const next = dedupeRecords(records)
  saveWithBackup(DATA_KEY, BACKUP_KEY, OLD_BACKUP_KEY, next, '工时')
}

export function loadLedgerEntries(): LedgerEntry[] {
  const main = readKey(LEDGER_KEY, parseLedgerStored)
  if (main) return main as LedgerEntry[]
  const backup = readKey(LEDGER_BACKUP_KEY, parseLedgerStored)
  if (backup) return backup as LedgerEntry[]
  const oldBackup = readKey(LEDGER_OLD_BACKUP_KEY, parseLedgerStored)
  return (oldBackup as LedgerEntry[] | null) ?? []
}

export function saveLedgerEntries(entries: LedgerEntry[]): void {
  if (typeof window === 'undefined') return
  const next = normalizeLedgerEntries(entries)
  saveWithBackup(LEDGER_KEY, LEDGER_BACKUP_KEY, LEDGER_OLD_BACKUP_KEY, next, '账目')
}

export function loadCustomCategories(): CustomLedgerCategory[] {
  const main = readKey(CATEGORY_KEY, parseCategoryStored)
  if (main) return main as CustomLedgerCategory[]
  const backup = readKey(CATEGORY_BACKUP_KEY, parseCategoryStored)
  if (backup) return backup as CustomLedgerCategory[]
  const oldBackup = readKey(CATEGORY_OLD_BACKUP_KEY, parseCategoryStored)
  return (oldBackup as CustomLedgerCategory[] | null) ?? []
}

export function saveCustomCategories(
  categories: CustomLedgerCategory[],
): void {
  if (typeof window === 'undefined') return
  const next = normalizeLedgerCategories(categories)
  saveWithBackup(
    CATEGORY_KEY,
    CATEGORY_BACKUP_KEY,
    CATEGORY_OLD_BACKUP_KEY,
    next,
    '分类',
  )
}

export function loadWorkProfiles(): WorkProfile[] {
  const main = readKey(PROFILE_KEY, parseWorkProfileStored)
  if (main) return main as WorkProfile[]
  const backup = readKey(PROFILE_BACKUP_KEY, parseWorkProfileStored)
  if (backup) return backup as WorkProfile[]
  const oldBackup = readKey(PROFILE_OLD_BACKUP_KEY, parseWorkProfileStored)
  if (oldBackup) return oldBackup as WorkProfile[]
  return ensureDefaultWorkProfile([])
}

export function saveWorkProfiles(profiles: WorkProfile[]): void {
  if (typeof window === 'undefined') return
  const next = ensureDefaultWorkProfile(dedupeWorkProfiles(profiles))
  saveWithBackup(
    PROFILE_KEY,
    PROFILE_BACKUP_KEY,
    PROFILE_OLD_BACKUP_KEY,
    next,
    '工作',
  )
}

export function loadBudgetTargets(): BudgetTargets {
  const loaded = readKey(BUDGET_KEY, parseBudgetStored)
  if (loaded) return loaded as BudgetTargets
  return { ...DEFAULT_BUDGET_TARGETS }
}

/** 是否存在任何本地主数据（键存在且可解析）。自动备份恢复用它判断“主数据为空”。 */
export function hasStoredAppData(): boolean {
  if (loadRecords().length > 0 || loadLedgerEntries().length > 0) return true
  if (loadCustomCategories().length > 0) return true
  if (loadWorkProfiles().some((profile) => profile.id !== 'work-default')) return true
  const budget = loadBudgetTargets()
  return budget.monthlyExpenseBudget > 0 || budget.monthlyIncomeGoal > 0
}

export function saveBudgetTargets(targets: BudgetTargets): void {
  if (typeof window === 'undefined') return
  const next = normalizeBudgetTargets(targets)
  try {
    const envelope: Envelope<BudgetTargets> = { __v: DATA_VERSION, data: next }
    window.localStorage.setItem(BUDGET_KEY, JSON.stringify(envelope))
  } catch {
    console.warn('[my-hours] 预算保存失败')
  }
}

function saveWithBackup(
  key: string,
  backupKey: string,
  oldBackupKey: string,
  data: StoredData,
  label: string,
): void {
  try {
    const current = window.localStorage.getItem(key)
    if (current !== null) {
      try {
        const previousBackup = window.localStorage.getItem(backupKey)
        if (previousBackup !== null) {
          try {
            window.localStorage.setItem(oldBackupKey, previousBackup)
          } catch {
            // 旧备份写失败不阻断本次保存
          }
        }
        window.localStorage.setItem(backupKey, current)
      } catch {
        // 备份写失败不阻断主写入
      }
    }
    const envelope: Envelope<StoredData> = { __v: DATA_VERSION, data }
    window.localStorage.setItem(key, JSON.stringify(envelope))
  } catch {
    console.warn(`[my-hours] ${label}保存失败`)
  }
}
