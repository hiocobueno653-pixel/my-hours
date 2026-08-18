import { describe, expect, it } from 'vitest'
import {
  loadCustomCategories,
  loadLedgerEntries,
  loadRecords,
  saveCustomCategories,
  saveLedgerEntries,
  saveRecords,
} from './persistence'

describe('persistence', () => {
  it('saves and loads work records', () => {
    window.localStorage.clear()
    const records = [
      { date: '2026-08-01', hours: 8, remark: '早班' },
      { date: '2026-08-02', hours: 7.5, remark: '晚班' },
    ]
    saveRecords(records)
    expect(loadRecords()).toEqual(records)
  })

  it('recovers work records from the backup when the main value is corrupted', () => {
    window.localStorage.clear()
    saveRecords([{ date: '2026-08-01', hours: 8, remark: 'first' }])
    saveRecords([{ date: '2026-08-02', hours: 9, remark: 'second' }])
    window.localStorage.setItem('my-hours.data.v1', '{broken')
    expect(loadRecords()).toEqual([
      { date: '2026-08-01', hours: 8, remark: 'first' },
    ])
  })

  it('saves and loads ledger entries independently', () => {
    window.localStorage.clear()
    const entries = [
      {
        id: 'entry-1',
        date: '2026-08-01',
        type: 'expense' as const,
        amount: 25,
        category: '餐饮',
        remark: '午饭',
      },
    ]
    saveLedgerEntries(entries)
    expect(loadLedgerEntries()).toEqual(entries)
  })

  it('saves and loads custom categories independently', () => {
    window.localStorage.clear()
    const categories = [
      { id: 'category-1', type: 'income' as const, name: '提成' },
      { id: 'category-2', type: 'expense' as const, name: '房租' },
    ]
    saveCustomCategories(categories)
    expect(loadCustomCategories()).toEqual(categories)
  })
})
