import { describe, expect, it, beforeEach } from 'vitest'
import {
  clearAutoBackups,
  hasStoredAppRecords,
  isAutoBackupSuppressed,
  loadAutoBackup,
  recoverAutoBackupIfNeeded,
  runAutoBackup,
  scheduleAutoBackup,
  suppressAutoBackup,
  type AutoBackupData,
} from './autoBackup'

function sampleData(): AutoBackupData {
  return {
    records: [{ date: '2026-08-01', hours: 8, remark: '自动备份', rate: 50, settled: true }],
    entries: [{
      id: 'wage-2026-08-01',
      date: '2026-08-01',
      type: 'income',
      amount: 400,
      category: '工资',
      remark: '结算工资',
      workDate: '2026-08-01',
    }],
    customCategories: [],
    workProfiles: [{ id: 'work-default', name: '默认工作', hourlyRate: 50 }],
    budgetTargets: { monthlyExpenseBudget: 0, monthlyIncomeGoal: 0 },
  }
}

beforeEach(async () => {
  window.localStorage.clear()
  // 重置模块级指纹与抑制标记，避免 worker 复用导致测试间串状态
  await clearAutoBackups()
})

describe('auto backup', () => {
  it('saves and reads a snapshot via localStorage fallback', async () => {
    const data = sampleData()
    const ok = await runAutoBackup(data)
    expect(ok).toBe(true)
    const loaded = await loadAutoBackup()
    expect(loaded?.records).toEqual(data.records)
    expect(loaded?.entries).toEqual(data.entries)
    expect(loaded?.workProfiles).toEqual(data.workProfiles)
  })

  it('does not create a backup when no real data exists', async () => {
    const empty: AutoBackupData = {
      records: [],
      entries: [],
      customCategories: [],
      workProfiles: [{ id: 'work-default', name: '默认工作', hourlyRate: 0 }],
      budgetTargets: { monthlyExpenseBudget: 0, monthlyIncomeGoal: 0 },
    }
    expect(hasStoredAppRecords(empty)).toBe(false)
    expect(await runAutoBackup(empty)).toBe(false)
    expect(await loadAutoBackup()).toBeNull()
  })

  it('falls back to localStorage when IndexedDB is unavailable', async () => {
    const original = globalThis.indexedDB
    Object.defineProperty(globalThis, 'indexedDB', {
      configurable: true,
      value: undefined,
    })
    try {
      const data = sampleData()
      expect(await runAutoBackup(data)).toBe(true)
      expect(window.localStorage.getItem('my-hours.autoBackup.v1')).not.toBeNull()
      expect(await loadAutoBackup()).not.toBeNull()
    } finally {
      Object.defineProperty(globalThis, 'indexedDB', {
        configurable: true,
        value: original,
      })
    }
  })

  it('recovers only when primary local data is missing', async () => {
    await runAutoBackup(sampleData())
    // primary data missing -> recover
    expect(await recoverAutoBackupIfNeeded()).not.toBeNull()
  })

  it('respects suppression after clearing data', async () => {
    await runAutoBackup(sampleData())
    suppressAutoBackup()
    expect(isAutoBackupSuppressed()).toBe(true)
    expect(await recoverAutoBackupIfNeeded()).toBeNull()
    clearAutoBackups()
  })

  it('schedules a backup and runs after delay', async () => {
    const data = sampleData()
    scheduleAutoBackup(data)
    await new Promise((resolve) => setTimeout(resolve, 2200))
    const loaded = await loadAutoBackup()
    expect(loaded?.records).toEqual(data.records)
  })
})
