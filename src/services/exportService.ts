import { Capacitor } from '@capacitor/core'
import { Directory, Encoding, Filesystem } from '@capacitor/filesystem'
import { Share } from '@capacitor/share'
import {
  buildLedgerCsv,
  buildLedgerRows,
  buildMonthCsv,
  buildMonthOverviewCsv,
  buildMonthOverviewRows,
  buildMonthRows,
  createBackupPayload,
} from '../data/backup'
import { todayISO } from '../data/dates'
import type { CustomLedgerCategory, LedgerEntry, WorkDayRecord } from '../data/types'

async function saveTextFile(
  filename: string,
  content: string,
  mimeType: string,
): Promise<void> {
  if (Capacitor.isNativePlatform()) {
    const result = await Filesystem.writeFile({
      path: filename,
      data: content,
      directory: Directory.Cache,
      encoding: Encoding.UTF8,
    })
    await Share.share({
      title: filename,
      url: result.uri,
      dialogTitle: '保存到云盘或文件',
    })
    return
  }

  const blob = new Blob([content], { type: mimeType })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.append(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
}

/** 将二维表写入 .xlsx 文件（原生走缓存+系统分享，网页走下载） */
async function saveTableAsExcel(
  filename: string,
  sheetName: string,
  rows: (string | number)[][],
): Promise<void> {
  // 动态加载 xlsx：仅导出 Excel 时才拉取，减小首屏体积
  const XLSX = await import('xlsx')
  const worksheet = XLSX.utils.aoa_to_sheet(rows)
  const workbook = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(workbook, worksheet, sheetName)
  const output = XLSX.write(workbook, { bookType: 'xlsx', type: 'base64' })
  if (Capacitor.isNativePlatform()) {
    // 不传 encoding：插件会把 data 按 base64 解码后写为二进制文件
    const result = await Filesystem.writeFile({
      path: filename,
      data: output,
      directory: Directory.Cache,
    })
    await Share.share({
      title: filename,
      url: result.uri,
      dialogTitle: '保存到云盘或文件',
    })
    return
  }
  const binary = XLSX.write(workbook, { bookType: 'xlsx', type: 'binary' })
  const buffer = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index += 1) {
    buffer[index] = binary.charCodeAt(index) & 0xff
  }
  const blob = new Blob([buffer], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.append(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
}

export async function exportBackupFile(
  records: WorkDayRecord[],
  entries: LedgerEntry[],
  customCategories: CustomLedgerCategory[],
): Promise<void> {
  const payload = JSON.stringify(
    createBackupPayload(records, entries, customCategories),
    null,
    2,
  )
  await saveTextFile(`我的工时备份-${todayISO()}.json`, payload, 'application/json')
}

export async function exportMonthCsv(
  yearMonth: string,
  records: WorkDayRecord[],
): Promise<void> {
  await saveTextFile(
    `我的工时-${yearMonth}.csv`,
    buildMonthCsv(yearMonth, records),
    'text/csv;charset=utf-8',
  )
}

export async function exportMonthExcel(
  yearMonth: string,
  records: WorkDayRecord[],
): Promise<void> {
  await saveTableAsExcel(
    `我的工时-${yearMonth}.xlsx`,
    '工时记录',
    buildMonthRows(yearMonth, records),
  )
}

export async function exportMonthOverviewCsv(
  yearMonth: string,
  records: WorkDayRecord[],
  entries: LedgerEntry[],
): Promise<void> {
  await saveTextFile(
    `我的工时账本-${yearMonth}.csv`,
    buildMonthOverviewCsv(yearMonth, records, entries),
    'text/csv;charset=utf-8',
  )
}

export async function exportMonthOverviewExcel(
  yearMonth: string,
  records: WorkDayRecord[],
  entries: LedgerEntry[],
): Promise<void> {
  await saveTableAsExcel(
    `我的工时账本-${yearMonth}.xlsx`,
    '本月概览',
    buildMonthOverviewRows(yearMonth, records, entries),
  )
}

export async function exportLedgerCsv(
  yearMonth: string,
  entries: LedgerEntry[],
  records: WorkDayRecord[],
): Promise<void> {
  await saveTextFile(
    `我的账本-${yearMonth}.csv`,
    buildLedgerCsv(yearMonth, entries, records),
    'text/csv;charset=utf-8',
  )
}

export async function exportLedgerExcel(
  yearMonth: string,
  entries: LedgerEntry[],
  records: WorkDayRecord[],
): Promise<void> {
  await saveTableAsExcel(
    `我的账本-${yearMonth}.xlsx`,
    '账本',
    buildLedgerRows(yearMonth, entries, records),
  )
}
