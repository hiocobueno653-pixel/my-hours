import { getMonthDates, weekdayName } from './dates'
import {
  dedupeLedgerCategories,
  dedupeLedgerEntries,
  formatMoney,
  getLedgerMonthSummary,
  normalizeLedgerCategories,
  normalizeLedgerEntries,
  sortLedgerEntries,
} from './ledger'
import {
  DEFAULT_BUDGET_TARGETS,
  dedupeWorkProfiles,
  ensureDefaultWorkProfile,
  normalizeBudgetTargets,
  normalizeWorkProfiles,
} from './profiles'
import {
  dedupeRecords,
  formatHours,
  getMonthSummary,
  getRecordByDate,
  normalizeRecord,
} from './records'
import type {
  BackupFile,
  BudgetTargets,
  CustomLedgerCategory,
  LedgerEntry,
  ParsedBackupData,
  WorkDayRecord,
  WorkProfile,
} from './types'

export function createBackupPayload(
  records: WorkDayRecord[],
  entries: LedgerEntry[],
  customCategories: CustomLedgerCategory[] = [],
  workProfiles: WorkProfile[] = [],
  budgetTargets: BudgetTargets = { ...DEFAULT_BUDGET_TARGETS },
): BackupFile {
  return {
    app: 'my-hours',
    version: 4,
    exportedAt: new Date().toISOString(),
    records: dedupeRecords(records),
    entries: dedupeLedgerEntries(entries),
    customCategories: dedupeLedgerCategories(customCategories),
    workProfiles: dedupeWorkProfiles(workProfiles),
    budgetTargets: normalizeBudgetTargets(budgetTargets),
  }
}

interface LegacyBackup {
  app?: string
  version?: number
  exportedAt?: string
  records?: unknown
  entries?: unknown
  customCategories?: unknown
  workProfiles?: unknown
  budgetTargets?: unknown
}

export function parseBackupText(text: string): ParsedBackupData {
  let parsed: unknown
  try {
    parsed = JSON.parse(text)
  } catch {
    throw new Error('备份文件不是有效 JSON')
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('备份文件格式不正确')
  }
  const backup = parsed as LegacyBackup
  if (backup.app !== 'my-hours') {
    throw new Error('备份文件格式不正确')
  }
  if (backup.version !== 1 && backup.version !== 2 && backup.version !== 3 && backup.version !== 4) {
    throw new Error('备份文件版本不支持')
  }
  if (!Array.isArray(backup.records)) {
    throw new Error('备份文件缺少工时记录')
  }
  const normalizedRecords = backup.records.map(normalizeRecord)
  if (normalizedRecords.some((record) => record === null)) {
    throw new Error('备份文件包含无效工时记录')
  }
  const entries = backup.version === 1 ? [] : backup.entries ?? []
  if (!Array.isArray(entries)) {
    throw new Error('备份文件账目数据格式不正确')
  }
  const normalizedEntries = normalizeLedgerEntries(entries)
  if (normalizedEntries.length !== entries.length) {
    throw new Error('备份文件包含无效账目')
  }
  let customCategories: CustomLedgerCategory[] = []
  if (backup.version >= 3) {
    if (!Array.isArray(backup.customCategories)) {
      throw new Error('备份文件缺少自定义分类')
    }
    const normalizedCategories = normalizeLedgerCategories(
      backup.customCategories,
    )
    if (normalizedCategories.length !== backup.customCategories.length) {
      throw new Error('备份文件包含无效自定义分类')
    }
    customCategories = dedupeLedgerCategories(normalizedCategories)
  }
  let workProfiles: WorkProfile[] = []
  if (backup.version >= 4) {
    if (!Array.isArray(backup.workProfiles)) {
      throw new Error('备份文件缺少工作设置')
    }
    const normalizedProfiles = normalizeWorkProfiles(backup.workProfiles)
    if (normalizedProfiles.length !== backup.workProfiles.length) {
      throw new Error('备份文件包含无效工作设置')
    }
    workProfiles = ensureDefaultWorkProfile(
      dedupeWorkProfiles(normalizedProfiles),
    )
  } else {
    // v1-v3 备份默认只有一份默认工作
    workProfiles = ensureDefaultWorkProfile([])
  }
  const budgetTargets = normalizeBudgetTargets(backup.budgetTargets)
  return {
    records: dedupeRecords(
      normalizedRecords.filter(
        (record): record is WorkDayRecord => record !== null,
      ),
    ),
    entries: dedupeLedgerEntries(normalizedEntries),
    customCategories,
    workProfiles,
    budgetTargets,
  }
}

function csvCell(value: string): string {
  if (/[",\r\n]/.test(value)) {
    return `"${value.replaceAll('"', '""')}"`
  }
  return value
}

export function buildMonthCsv(
  yearMonth: string,
  records: WorkDayRecord[],
): string {
  const lines = [['日期', '星期', '工时', '备注'].map(csvCell).join(',')]
  for (const day of getMonthDates(yearMonth)) {
    const record = getRecordByDate(records, day.date)
    lines.push(
      [
        csvCell(day.date),
        csvCell(`星期${weekdayName(day.weekday)}`),
        record ? csvCell(formatHours(record.hours)) : '',
        record ? csvCell(record.remark) : '',
      ].join(','),
    )
  }
  const summary = getMonthSummary(records, yearMonth)
  lines.push(
    [
      csvCell('月总计'),
      csvCell(`工作${summary.workDays}天`),
      csvCell(formatHours(summary.totalHours)),
      '',
    ].join(','),
  )
  return `\uFEFF${lines.join('\r\n')}`
}

export function buildMonthOverviewCsv(
  yearMonth: string,
  records: WorkDayRecord[],
  entries: LedgerEntry[],
): string {
  const lines = [
    ['日期', '星期', '工时', '备注', '收入', '支出'].map(csvCell).join(','),
  ]
  for (const day of getMonthDates(yearMonth)) {
    const record = getRecordByDate(records, day.date)
    const dayEntries = entries.filter((entry) => entry.date === day.date)
    const income =
      Math.round(
        dayEntries
          .filter((entry) => entry.type === 'income')
          .reduce((sum, entry) => sum + entry.amount, 0) * 100,
      ) / 100
    const expense =
      Math.round(
        dayEntries
          .filter((entry) => entry.type === 'expense')
          .reduce((sum, entry) => sum + entry.amount, 0) * 100,
      ) / 100
    lines.push(
      [
        csvCell(day.date),
        csvCell(`星期${weekdayName(day.weekday)}`),
        record ? csvCell(formatHours(record.hours)) : '',
        record ? csvCell(record.remark) : '',
        csvCell(formatMoney(income)),
        csvCell(formatMoney(expense)),
      ].join(','),
    )
  }
  const hoursSummary = getMonthSummary(records, yearMonth)
  const ledgerSummary = getLedgerMonthSummary(entries, yearMonth)
  lines.push(
    [
      csvCell('月总计'),
      csvCell(`工作${hoursSummary.workDays}天`),
      csvCell(formatHours(hoursSummary.totalHours)),
      '',
      csvCell(formatMoney(ledgerSummary.income)),
      csvCell(formatMoney(ledgerSummary.expense)),
    ].join(','),
  )
  lines.push(
    [
      csvCell('月结余'),
      '',
      '',
      '',
      csvCell(formatMoney(ledgerSummary.balance)),
      '',
    ].join(','),
  )
  const categoryTotals = new Map<string, { name: string; type: 'income' | 'expense'; total: number }>()
  for (const entry of entries) {
    if (!entry.date.startsWith(`${yearMonth}-`)) continue
    const key = `${entry.type}:${entry.category}`
    const current = categoryTotals.get(key)
    categoryTotals.set(key, {
      name: entry.category,
      type: entry.type,
      total: Math.round(((current?.total ?? 0) + entry.amount) * 100) / 100,
    })
  }
  const categoryRows = Array.from(categoryTotals.values()).sort(
    (a, b) => b.total - a.total,
  )
  for (const row of categoryRows.filter((row) => row.type === 'income')) {
    lines.push(
      [
        csvCell('收入分类'),
        csvCell(row.name),
        '',
        '',
        csvCell(formatMoney(row.total)),
        '',
      ].join(','),
    )
  }
  for (const row of categoryRows.filter((row) => row.type === 'expense')) {
    lines.push(
      [
        csvCell('支出分类'),
        csvCell(row.name),
        '',
        '',
        '',
        csvCell(formatMoney(row.total)),
      ].join(','),
    )
  }
  return `\uFEFF${lines.join('\r\n')}`
}

export function buildLedgerCsv(
  yearMonth: string,
  entries: LedgerEntry[],
  records: WorkDayRecord[] = [],
): string {
  const lines = [
    ['日期', '类型', '分类', '金额', '关联工时', '备注'].map(csvCell).join(','),
  ]
  const monthEntries = sortLedgerEntries(
    entries.filter((entry) => entry.date.startsWith(`${yearMonth}-`)),
  )
  for (const entry of monthEntries) {
    const linkedRecord = entry.workDate
      ? getRecordByDate(records, entry.workDate)
      : undefined
    lines.push(
      [
        csvCell(entry.date),
        csvCell(entry.type === 'income' ? '收入' : '支出'),
        csvCell(entry.category),
        csvCell(formatMoney(entry.amount)),
        linkedRecord ? csvCell(`${formatHours(linkedRecord.hours)}小时`) : '',
        csvCell(entry.remark),
      ].join(','),
    )
  }
  const summary = getLedgerMonthSummary(entries, yearMonth)
  lines.push(['', '', '月收入', formatMoney(summary.income), '', ''].join(','))
  lines.push(['', '', '月支出', formatMoney(summary.expense), '', ''].join(','))
  lines.push(['', '', '月结余', formatMoney(summary.balance), '', ''].join(','))
  return `\uFEFF${lines.join('\r\n')}`
}
export function buildMonthRows(
  yearMonth: string,
  records: WorkDayRecord[],
): string[][] {
  const rows: string[][] = [['日期', '星期', '工时', '备注']]
  for (const day of getMonthDates(yearMonth)) {
    const record = getRecordByDate(records, day.date)
    rows.push([
      day.date,
      `星期${weekdayName(day.weekday)}`,
      record ? formatHours(record.hours) : '',
      record ? record.remark : '',
    ])
  }
  const summary = getMonthSummary(records, yearMonth)
  rows.push(['月总计', `工作${summary.workDays}天`, formatHours(summary.totalHours), ''])
  return rows
}

export function buildMonthOverviewRows(
  yearMonth: string,
  records: WorkDayRecord[],
  entries: LedgerEntry[],
): string[][] {
  const rows: string[][] = [['日期', '星期', '工时', '备注', '收入', '支出']]
  for (const day of getMonthDates(yearMonth)) {
    const record = getRecordByDate(records, day.date)
    const dayEntries = entries.filter((entry) => entry.date === day.date)
    const income =
      Math.round(
        dayEntries
          .filter((entry) => entry.type === 'income')
          .reduce((sum, entry) => sum + entry.amount, 0) * 100,
      ) / 100
    const expense =
      Math.round(
        dayEntries
          .filter((entry) => entry.type === 'expense')
          .reduce((sum, entry) => sum + entry.amount, 0) * 100,
      ) / 100
    rows.push([
      day.date,
      `星期${weekdayName(day.weekday)}`,
      record ? formatHours(record.hours) : '',
      record ? record.remark : '',
      formatMoney(income),
      formatMoney(expense),
    ])
  }
  const hoursSummary = getMonthSummary(records, yearMonth)
  const ledgerSummary = getLedgerMonthSummary(entries, yearMonth)
  rows.push([
    '月总计',
    `工作${hoursSummary.workDays}天`,
    formatHours(hoursSummary.totalHours),
    '',
    formatMoney(ledgerSummary.income),
    formatMoney(ledgerSummary.expense),
  ])
  rows.push(['月结余', '', '', '', formatMoney(ledgerSummary.balance), ''])
  const categoryTotals = new Map<string, { name: string; type: 'income' | 'expense'; total: number }>()
  for (const entry of entries) {
    if (!entry.date.startsWith(`${yearMonth}-`)) continue
    const key = `${entry.type}:${entry.category}`
    const current = categoryTotals.get(key)
    categoryTotals.set(key, {
      name: entry.category,
      type: entry.type,
      total: Math.round(((current?.total ?? 0) + entry.amount) * 100) / 100,
    })
  }
  const categoryRows = Array.from(categoryTotals.values()).sort(
    (a, b) => b.total - a.total,
  )
  for (const row of categoryRows.filter((row) => row.type === 'income')) {
    rows.push(['收入分类', row.name, '', '', formatMoney(row.total), ''])
  }
  for (const row of categoryRows.filter((row) => row.type === 'expense')) {
    rows.push(['支出分类', row.name, '', '', '', formatMoney(row.total)])
  }
  return rows
}

export function buildLedgerRows(
  yearMonth: string,
  entries: LedgerEntry[],
  records: WorkDayRecord[] = [],
): string[][] {
  const rows: string[][] = [['日期', '类型', '分类', '金额', '关联工时', '备注']]
  const monthEntries = sortLedgerEntries(
    entries.filter((entry) => entry.date.startsWith(`${yearMonth}-`)),
  )
  for (const entry of monthEntries) {
    const linkedRecord = entry.workDate
      ? getRecordByDate(records, entry.workDate)
      : undefined
    rows.push([
      entry.date,
      entry.type === 'income' ? '收入' : '支出',
      entry.category,
      formatMoney(entry.amount),
      linkedRecord ? `${formatHours(linkedRecord.hours)}小时` : '',
      entry.remark,
    ])
  }
  const summary = getLedgerMonthSummary(entries, yearMonth)
  rows.push(['', '', '月收入', formatMoney(summary.income), '', ''])
  rows.push(['', '', '月支出', formatMoney(summary.expense), '', ''])
  rows.push(['', '', '月结余', formatMoney(summary.balance), '', ''])
  return rows
}

