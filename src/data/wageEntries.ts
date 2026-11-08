import { getRecordByDate, getRecordPay } from './records'
import type { LedgerEntry, WorkDayRecord, WorkProfile } from './types'

export const WAGE_ENTRY_ID_PREFIX = 'wage-'

/** 某天工资对应的系统账目 id。结算状态变化时会重建或删除该账目。 */
export function getWageEntryId(date: string): string {
  return `${WAGE_ENTRY_ID_PREFIX}${date}`
}

export function isWageEntryForDate(
  entry: LedgerEntry,
  date: string,
): boolean {
  return entry.id === getWageEntryId(date)
}

/**
 * 旧版「同时记收入」遗留账目：关联某天工时的非系统收入（id 非 wage-*）。
 * 旧版本里它就是同一笔结算工资，升级/导入时由对账替换为工资账目，避免双计。
 * （与 DayEditor 的 legacyLinkedIncome 语义一致）
 */
function isLegacyLinkedIncome(entry: LedgerEntry, date: string): boolean {
  return (
    entry.type === 'income' &&
    entry.workDate === date &&
    !isWageEntryForDate(entry, date)
  )
}

function createWageEntry(date: string, amount: number): LedgerEntry {
  return {
    id: getWageEntryId(date),
    date,
    type: 'income',
    amount,
    category: '工资',
    remark: '结算工资',
    workDate: date,
  }
}

/**
 * 按一条工时记录的状态同步其系统工资账目：
 * 已结算且有工资 → 重建为最新金额（旧式关联收入一并替换，避免双计）；
 * 未结算或工资为 0 → 删除系统账目。
 * 不触碰用户手动录入的其他账目。
 */
export function syncWageEntryForDate(
  records: WorkDayRecord[],
  entries: LedgerEntry[],
  workProfiles: WorkProfile[],
  date: string,
): LedgerEntry[] {
  const record = getRecordByDate(records, date)
  const pay = record ? getRecordPay(record, workProfiles) : 0
  const shouldSync = Boolean(record?.settled && pay > 0)
  const next = entries.filter(
    (entry) =>
      !isWageEntryForDate(entry, date) &&
      !(shouldSync && isLegacyLinkedIncome(entry, date)),
  )
  if (!shouldSync) return next
  return [...next, createWageEntry(date, pay)]
}

/** 对整组工时记录执行一次结算对账：
 *  - 已结算且有工资的天：补/保工资收入账目，并替换旧式关联收入，保证不重不漏；
 *  - 未结算或零工资的天：移除残留的系统工资账目；
 *  - 已存在账目的金额不动（用户手动编辑过的保持原样）。
 *  无任何变化时返回原数组引用：启动对账据此跳过全量回写与备份轮转。 */
export function syncWageEntries(
  records: WorkDayRecord[],
  entries: LedgerEntry[],
  workProfiles: WorkProfile[],
): LedgerEntry[] {
  const wanted = new Set<string>()
  for (const record of records) {
    const pay = getRecordPay(record, workProfiles)
    if (record.settled && pay > 0) wanted.add(record.date)
  }
  let changed = false
  const retained = entries.filter((entry) => {
    if (isWageEntryForDate(entry, entry.date)) {
      const keep = wanted.has(entry.date)
      if (!keep) changed = true
      return keep
    }
    // 旧式关联收入：命中已结算日期则替换为工资账目，避免双计
    if (
      entry.type === 'income' &&
      entry.workDate !== undefined &&
      wanted.has(entry.workDate) &&
      !isWageEntryForDate(entry, entry.workDate)
    ) {
      changed = true
      return false
    }
    return true
  })
  for (const date of wanted) {
    if (retained.some((entry) => isWageEntryForDate(entry, date))) continue
    const record = getRecordByDate(records, date)
    if (!record) continue
    const pay = getRecordPay(record, workProfiles)
    if (pay <= 0) continue
    retained.push(createWageEntry(date, pay))
    changed = true
  }
  return changed ? retained : entries
}
