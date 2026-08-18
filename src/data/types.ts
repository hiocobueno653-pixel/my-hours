export interface WorkDayRecord {
  date: string
  hours: number
  remark: string
  /** 关联的工作 id（缺省为默认工作） */
  workId?: string
  /** 记录时的时薪快照（元/小时）；改工作时薪不影响历史记录 */
  rate?: number
  /** 结算标记：工资已结算/未结算 */
  settled?: boolean
}

export interface MonthSummary {
  totalHours: number
  workDays: number
  averageHours: number
}

export type LedgerType = 'income' | 'expense'

export interface LedgerEntry {
  id: string
  date: string
  type: LedgerType
  amount: number
  category: string
  remark: string
  workDate?: string
}

export interface LedgerMonthSummary {
  income: number
  expense: number
  balance: number
}

export interface CustomLedgerCategory {
  id: string
  type: LedgerType
  name: string
}

/** 一份工作：独立时薪，用于工资自动计算与按工作统计 */
export interface WorkProfile {
  id: string
  name: string
  /** 时薪（元/小时），0 表示未设置 */
  hourlyRate: number
}

/** 每月预算与收入目标；0 表示未设置 */
export interface BudgetTargets {
  monthlyExpenseBudget: number
  monthlyIncomeGoal: number
}

export interface BackupFile {
  app: 'my-hours'
  version: 4
  exportedAt: string
  records: WorkDayRecord[]
  entries: LedgerEntry[]
  customCategories: CustomLedgerCategory[]
  workProfiles: WorkProfile[]
  budgetTargets: BudgetTargets
}

export interface ParsedBackupData {
  records: WorkDayRecord[]
  entries: LedgerEntry[]
  customCategories: CustomLedgerCategory[]
  workProfiles: WorkProfile[]
  budgetTargets: BudgetTargets
}
