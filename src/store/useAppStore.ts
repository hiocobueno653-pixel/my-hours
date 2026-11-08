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
  MAX_HOURLY_RATE,
  MAX_WORK_NAME_LENGTH,
  normalizeBudgetTargets,
} from '../data/profiles'
import { dedupeRecords, getRecordPay, MAX_FIXED_PAY } from '../data/records'
import {
  isWageEntryForDate,
  syncWageEntries,
  syncWageEntryForDate,
} from '../data/wageEntries'
import {
  clearAutoBackups,
  recoverAutoBackupIfNeeded,
  scheduleAutoBackup,
  type AutoBackupData,
} from '../services/autoBackup'
import type {
  BudgetTargets,
  CustomLedgerCategory,
  LedgerEntry,
  LedgerType,
  WorkDayRecord,
  WorkProfile,
} from '../data/types'

// 「只记工时」变体（VITE_HOURS_ONLY=1 构建）：不生成/对账工资账本条目（结算仅是标记）
const HOURS_ONLY = import.meta.env.VITE_HOURS_ONLY === '1'

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
    options?: { workId?: string; rate?: number; fixedPay?: number; settled?: boolean },
  ) => void
  deleteDay: (date: string) => LedgerEntry | undefined
  saveLedgerEntry: (entry: LedgerEntry) => void
  deleteLedgerEntry: (id: string) => void
  addCustomCategory: (type: LedgerType, name: string) => boolean
  deleteCustomCategory: (id: string) => boolean
  saveWorkProfile: (profile: WorkProfile) => boolean
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

// 启动阶段先快速读取本机主数据（同步），再让自动备份恢复异步完成：
// 首屏不等待 IndexedDB / 文件系统，避免启动变慢。
const bootRecords = loadRecords()
const bootProfiles = loadWorkProfiles()
const bootLedger = loadLedgerEntries()
// 「只记工时」变体不生成/对账工资账本条目（结算仅是记录的标记）
const bootEntries = HOURS_ONLY
  ? bootLedger
  : syncWageEntries(bootRecords, bootLedger, bootProfiles)
// 对账有变化才回写：无变化时避免每次冷启动全量重写账目并轮转两代备份
// （否则启动一次就把主键与备份拍成三代相同内容，备份失去分层保护）
if (bootEntries !== bootLedger) saveLedgerEntries(bootEntries)

// 自动备份恢复仅在主数据为空且用户未主动清空时执行。恢复成功后立即回写主存储，
// 并清除旧快照，避免下次启动再次恢复同一份数据。
void recoverAutoBackupIfNeeded().then((payload) => {
  if (!payload) return
  useAppStore.getState().replaceAll(payload)
})

function toAutoBackupData(state: AppState): AutoBackupData {
  return {
    records: state.records,
    entries: state.entries,
    customCategories: state.customCategories,
    workProfiles: state.workProfiles,
    budgetTargets: state.budgetTargets,
  }
}

function autoBackup(state: AppState): void {
  scheduleAutoBackup(toAutoBackupData(state))
}

export const useAppStore = create<AppState>((set, get) => ({
  records: bootRecords,
  entries: bootEntries,
  customCategories: loadCustomCategories(),
  workProfiles: bootProfiles,
  budgetTargets: loadBudgetTargets(),

  saveDay: (date, hours, remark, options) => {
    const record: WorkDayRecord = { date, hours, remark }
    if (options?.workId && options.workId !== DEFAULT_WORK_ID) {
      record.workId = options.workId
    }
    if (
      options?.rate !== undefined &&
      Number.isFinite(options.rate) &&
      options.rate > 0 &&
      // 与导入归一化（normalizeRecord）同口径：超上限不入库，避免直写与导入结果不一致
      options.rate <= MAX_HOURLY_RATE
    ) {
      record.rate = Math.round(options.rate * 100) / 100
    }
    if (
      options?.fixedPay !== undefined &&
      Number.isFinite(options.fixedPay) &&
      options.fixedPay >= 0 &&
      options.fixedPay <= MAX_FIXED_PAY
    ) {
      record.fixedPay = Math.round(options.fixedPay * 100) / 100
    }
    if (options?.settled !== undefined && options.settled) record.settled = true
    const next = dedupeRecords([
      ...get().records.filter((item) => item.date !== date),
      record,
    ])
    persistRecords(next)
    const nextEntries = HOURS_ONLY
      ? get().entries
      : syncWageEntryForDate(
          next,
          get().entries,
          get().workProfiles,
          date,
        )
    saveLedgerEntries(nextEntries)
    set({ records: next })
    set({ entries: nextEntries })
    autoBackup(get())
  },

  deleteDay: (date) => {
    const next = get().records.filter((record) => record.date !== date)
    const removed = get().entries.find((entry) => isWageEntryForDate(entry, date))
    const nextEntries = HOURS_ONLY
      ? get().entries
      : syncWageEntryForDate(
          next,
          get().entries,
          get().workProfiles,
          date,
        )
    persistRecords(next)
    saveLedgerEntries(nextEntries)
    set({ records: next })
    set({ entries: nextEntries })
    autoBackup(get())
    return removed
  },

  saveLedgerEntry: (entry) => {
    const next = normalizeLedgerEntries([
      ...get().entries.filter((item) => item.id !== entry.id),
      entry,
    ])
    saveLedgerEntries(next)
    set({ entries: next })
    autoBackup(get())
  },

  deleteLedgerEntry: (id) => {
    const next = get().entries.filter((entry) => entry.id !== id)
    saveLedgerEntries(next)
    set({ entries: next })
    autoBackup(get())
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
    autoBackup(get())
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
    autoBackup(get())
    return true
  },

  saveWorkProfile: (profile) => {
    const normalizedName = profile.name.trim().slice(0, MAX_WORK_NAME_LENGTH)
    if (!normalizedName) return false
    const duplicate = get().workProfiles.some(
      (item) => item.id !== profile.id && item.name === normalizedName,
    )
    if (duplicate) return false
    const next = ensureDefaultWorkProfile(
      dedupeWorkProfiles([
        ...get().workProfiles.filter((item) => item.id !== profile.id),
        { ...profile, name: normalizedName },
      ]),
    )
    saveWorkProfiles(next)
    set({ workProfiles: next })
    autoBackup(get())
    return true
  },

  deleteWorkProfile: (id) => {
    if (id === DEFAULT_WORK_ID) return
    const { records, workProfiles } = get()
    const removed = workProfiles.find((profile) => profile.id === id)
    if (!removed) return
    // 关联记录归回默认工作；时薪快照保留，历史工资不受影响
    const nextRecords = records.map((record) => {
      if (record.workId !== id) return record
      const { workId: _dropped, ...rest } = record
      return rest
    })
    const deduped = dedupeRecords(nextRecords)
    const nextProfiles = ensureDefaultWorkProfile(
      workProfiles.filter((profile) => profile.id !== id),
    )
    persistRecords(deduped)
    saveWorkProfiles(nextProfiles)
    set({ records: deduped, workProfiles: nextProfiles })
    autoBackup(get())
  },

  setRecordSettled: (date, settled) => {
    const records = get().records
    const next = records.map((record) => {
      if (record.date !== date) return record
      if (settled) return { ...record, settled: true }
      const { settled: _removed, ...rest } = record
      return rest
    })
    const deduped = dedupeRecords(next)
    persistRecords(deduped)
    const nextEntries = HOURS_ONLY
      ? get().entries
      : syncWageEntryForDate(
          deduped,
          get().entries,
          get().workProfiles,
          date,
        )
    saveLedgerEntries(nextEntries)
    set({ records: deduped })

    // 结算状态统一由 syncWageEntryForDate 对账：生成/更新或删除系统工资账目
    set({ entries: nextEntries })
    autoBackup(get())
  },

  settleMonth: (yearMonth, settled) => {
    const workProfiles = get().workProfiles
    const records = get().records
    const next = records.map((record) => {
      if (!record.date.startsWith(`${yearMonth}-`)) return record
      if (getRecordPay(record, workProfiles) <= 0) return record
      if (settled) return { ...record, settled: true }
      const { settled: _removed, ...rest } = record
      return rest
    })
    const deduped = dedupeRecords(next)
    persistRecords(deduped)
    set({ records: deduped })

    // 结算/撤销时同步本月工资收入账目（「只记工时」变体跳过：结算只是标记）
    if (!HOURS_ONLY) {
      let nextEntries = get().entries
      for (const record of deduped) {
        if (!record.date.startsWith(`${yearMonth}-`)) continue
        nextEntries = syncWageEntryForDate(
          deduped,
          nextEntries,
          workProfiles,
          record.date,
        )
      }
      saveLedgerEntries(nextEntries)
      set({ entries: nextEntries })
    }
    autoBackup(get())
  },

  saveBudgetTargets: (targets) => {
    const next = normalizeBudgetTargets(targets)
    saveBudgetTargets(next)
    set({ budgetTargets: next })
    autoBackup(get())
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
    void clearAutoBackups()
  },

  replaceAll: ({ records, entries, customCategories, workProfiles, budgetTargets }) => {
    const nextRecords = dedupeRecords(records)
    const nextCategories = dedupeLedgerCategories(customCategories)
    const nextProfiles = ensureDefaultWorkProfile(
      dedupeWorkProfiles(workProfiles ?? []),
    )
    const nextBudget = normalizeBudgetTargets(budgetTargets)
    // 导入后对账：备份里已结算但缺收入账目的记录补齐，已结算金额全部进入收入
    // （「只记工时」变体跳过对账，仅保留备份中原有账目数据）
    const nextEntries = HOURS_ONLY
      ? normalizeLedgerEntries(entries)
      : syncWageEntries(
          nextRecords,
          normalizeLedgerEntries(entries),
          nextProfiles,
        )
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
    autoBackup(get())
  },
}))
