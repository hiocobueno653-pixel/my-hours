import { create } from 'zustand'
import {
  DEFAULT_LEDGER_CATEGORIES,
  dedupeLedgerCategories,
  isLedgerCategoryInUse,
  MAX_CATEGORY_NAME_LENGTH,
  normalizeLedgerEntries,
} from '../data/ledger'
import {
  loadBudgetTargets,
  loadCustomCategories,
  loadLedgerEntries,
  loadRecords,
  loadWorkProfiles,
  saveBudgetTargets,
  saveCustomCategories,
  saveLedgerEntries,
  saveRecords,
  saveWorkProfiles,
} from '../data/persistence'
import {
  DEFAULT_WORK_ID,
  dedupeWorkProfiles,
  ensureDefaultWorkProfile,
  normalizeBudgetTargets,
} from '../data/profiles'
import { dedupeRecords } from '../data/records'
import type {
  BudgetTargets,
  CustomLedgerCategory,
  LedgerEntry,
  LedgerType,
  WorkDayRecord,
  WorkProfile,
} from '../data/types'

interface AppState {
  records: WorkDayRecord[]
  entries: LedgerEntry[]
  customCategories: CustomLedgerCategory[]
  workProfiles: WorkProfile[]
  budgetTargets: BudgetTargets
  saveDay: (
    date: string,
    hours: number,
    remark: string,
    options?: { workId?: string; rate?: number; settled?: boolean },
  ) => void
  deleteDay: (date: string) => void
  saveLedgerEntry: (entry: LedgerEntry) => void
  deleteLedgerEntry: (id: string) => void
  addCustomCategory: (type: LedgerType, name: string) => boolean
  deleteCustomCategory: (id: string) => boolean
  saveWorkProfile: (profile: WorkProfile) => void
  deleteWorkProfile: (id: string) => void
  setRecordSettled: (date: string, settled: boolean) => void
  settleMonth: (yearMonth: string, settled: boolean) => void
  saveBudgetTargets: (targets: BudgetTargets) => void
  clearAll: () => void
  replaceAll: (data: {
    records: WorkDayRecord[]
    entries: LedgerEntry[]
    customCategories: CustomLedgerCategory[]
    workProfiles: WorkProfile[]
    budgetTargets: BudgetTargets
  }) => void
}

function persistRecords(records: WorkDayRecord[]): void {
  saveRecords(records)
}

export const useAppStore = create<AppState>((set, get) => ({
  records: loadRecords(),
  entries: loadLedgerEntries(),
  customCategories: loadCustomCategories(),
  workProfiles: loadWorkProfiles(),
  budgetTargets: loadBudgetTargets(),

  saveDay: (date, hours, remark, options) => {
    const record: WorkDayRecord = { date, hours, remark }
    if (options?.workId && options.workId !== DEFAULT_WORK_ID) {
      record.workId = options.workId
    }
    if (options?.rate !== undefined && Number.isFinite(options.rate) && options.rate > 0) {
      record.rate = Math.round(options.rate * 100) / 100
    }
    if (options?.settled) record.settled = true
    const next = dedupeRecords([
      ...get().records.filter((item) => item.date !== date),
      record,
    ])
    persistRecords(next)
    set({ records: next })
  },

  deleteDay: (date) => {
    const next = get().records.filter((record) => record.date !== date)
    persistRecords(next)
    set({ records: next })
  },

  saveLedgerEntry: (entry) => {
    const next = normalizeLedgerEntries([
      ...get().entries.filter((item) => item.id !== entry.id),
      entry,
    ])
    saveLedgerEntries(next)
    set({ entries: next })
  },

  deleteLedgerEntry: (id) => {
    const next = get().entries.filter((entry) => entry.id !== id)
    saveLedgerEntries(next)
    set({ entries: next })
  },

  addCustomCategory: (type, name) => {
    const normalized = name.trim().slice(0, MAX_CATEGORY_NAME_LENGTH)
    if (!normalized) return false
    if (DEFAULT_LEDGER_CATEGORIES[type].includes(normalized)) return false
    const duplicate = get().customCategories.some(
      (category) => category.type === type && category.name === normalized,
    )
    if (duplicate) return false
    const next = dedupeLedgerCategories([
      ...get().customCategories,
      {
        id: `category-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
        type,
        name: normalized,
      },
    ])
    saveCustomCategories(next)
    set({ customCategories: next })
    return true
  },

  deleteCustomCategory: (id) => {
    const category = get().customCategories.find((item) => item.id === id)
    if (!category) return false
    if (isLedgerCategoryInUse(get().entries, category.type, category.name)) {
      return false
    }
    const next = get().customCategories.filter((item) => item.id !== id)
    saveCustomCategories(next)
    set({ customCategories: next })
    return true
  },

  saveWorkProfile: (profile) => {
    const next = ensureDefaultWorkProfile(
      dedupeWorkProfiles([
        ...get().workProfiles.filter((item) => item.id !== profile.id),
        profile,
      ]),
    )
    saveWorkProfiles(next)
    set({ workProfiles: next })
  },

  deleteWorkProfile: (id) => {
    if (id === DEFAULT_WORK_ID) return
    const { records, workProfiles } = get()
    const removed = workProfiles.find((profile) => profile.id === id)
    if (!removed) return
    // 关联记录归回默认工作；时薪快照保留，历史工资不受影响
    const nextRecords = records.map((record) =>
      record.workId === id ? { ...record } : record,
    )
    for (const record of nextRecords) {
      if (record.workId === id) delete record.workId
    }
    const deduped = dedupeRecords(nextRecords)
    const nextProfiles = ensureDefaultWorkProfile(
      workProfiles.filter((profile) => profile.id !== id),
    )
    persistRecords(deduped)
    saveWorkProfiles(nextProfiles)
    set({ records: deduped, workProfiles: nextProfiles })
  },

  setRecordSettled: (date, settled) => {
    const next = get().records.map((record) => {
      if (record.date !== date) return record
      if (settled) return { ...record, settled: true }
      const { settled: _removed, ...rest } = record
      return rest
    })
    const deduped = dedupeRecords(next)
    persistRecords(deduped)
    set({ records: deduped })
  },

  settleMonth: (yearMonth, settled) => {
    const next = get().records.map((record) => {
      if (!record.date.startsWith(`${yearMonth}-`)) return record
      if (record.hours * (record.rate ?? 0) <= 0) return record
      if (settled) return { ...record, settled: true }
      const { settled: _removed, ...rest } = record
      return rest
    })
    const deduped = dedupeRecords(next)
    persistRecords(deduped)
    set({ records: deduped })
  },

  saveBudgetTargets: (targets) => {
    const next = normalizeBudgetTargets(targets)
    saveBudgetTargets(next)
    set({ budgetTargets: next })
  },

  clearAll: () => {
    saveRecords([])
    saveLedgerEntries([])
    saveCustomCategories([])
    const profiles = ensureDefaultWorkProfile([])
    saveWorkProfiles(profiles)
    const budget: BudgetTargets = { monthlyExpenseBudget: 0, monthlyIncomeGoal: 0 }
    saveBudgetTargets(budget)
    set({
      records: [],
      entries: [],
      customCategories: [],
      workProfiles: profiles,
      budgetTargets: budget,
    })
  },

  replaceAll: ({ records, entries, customCategories, workProfiles, budgetTargets }) => {
    const nextRecords = dedupeRecords(records)
    const nextEntries = normalizeLedgerEntries(entries)
    const nextCategories = dedupeLedgerCategories(customCategories)
    const nextProfiles = ensureDefaultWorkProfile(
      dedupeWorkProfiles(workProfiles ?? []),
    )
    const nextBudget = normalizeBudgetTargets(budgetTargets)
    saveRecords(nextRecords)
    saveLedgerEntries(nextEntries)
    saveCustomCategories(nextCategories)
    saveWorkProfiles(nextProfiles)
    saveBudgetTargets(nextBudget)
    set({
      records: nextRecords,
      entries: nextEntries,
      customCategories: nextCategories,
      workProfiles: nextProfiles,
      budgetTargets: nextBudget,
    })
  },
}))
