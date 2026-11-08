import { describe, expect, it } from 'vitest'
import {
  buildLedgerCsv,
  buildMonthCsv,
  buildMonthOverviewCsv,
  createBackupPayload,
  parseBackupText,
} from './backup'

const records = [
  { date: '2026-08-01', hours: 8, remark: '普通班' },
  { date: '2026-08-02', hours: 8.5, remark: '含,逗号' },
]

const entries = [
  {
    id: 'entry-1',
    date: '2026-08-01',
    type: 'income' as const,
    amount: 5000,
    category: '工资',
    remark: '8月工资',
  },
  {
    id: 'entry-2',
    date: '2026-08-02',
    type: 'expense' as const,
    amount: 35.5,
    category: '餐饮',
    remark: '午饭,饮料',
    workDate: '2026-08-02',
  },
]

const customCategories = [
  { id: 'category-1', type: 'income' as const, name: '提成' },
  { id: 'category-2', type: 'expense' as const, name: '房租' },
]

const workProfiles = [
  { id: 'work-default', name: '工地A', hourlyRate: 25 },
  { id: 'work-tutor', name: '家教', hourlyRate: 50 },
]

const budgetTargets = {
  monthlyExpenseBudget: 3000,
  monthlyIncomeGoal: 8000,
}

describe('backup helpers', () => {
  it('creates a version 4 payload with records, entries, categories, work and budget', () => {
    const payload = createBackupPayload(
      records,
      entries,
      customCategories,
      workProfiles,
      budgetTargets,
    )
    expect(payload.app).toBe('my-hours')
    expect(payload.version).toBe(4)
    expect(payload.records).toEqual(records)
    expect(payload.entries).toEqual(entries)
    expect(payload.customCategories).toEqual(customCategories)
    expect(payload.workProfiles).toEqual(workProfiles)
    expect(payload.budgetTargets).toEqual(budgetTargets)
  })

  it('parses a valid version 4 backup', () => {
    const payload = createBackupPayload(
      records,
      entries,
      customCategories,
      workProfiles,
      budgetTargets,
    )
    const parsed = parseBackupText(JSON.stringify(payload))
    expect(parsed).toEqual({
      records,
      entries,
      customCategories,
      workProfiles,
      budgetTargets,
    })
  })

  it('parses a legacy version 2 backup without custom categories', () => {
    const payload = {
      app: 'my-hours',
      version: 2,
      exportedAt: '2026-08-16T00:00:00.000Z',
      records,
      entries,
    }
    expect(parseBackupText(JSON.stringify(payload))).toEqual({
      records,
      entries,
      customCategories: [],
      workProfiles: [{ id: 'work-default', name: '默认工作', hourlyRate: 0 }],
      budgetTargets: { monthlyExpenseBudget: 0, monthlyIncomeGoal: 0 },
    })
  })

  it('parses a legacy version 1 backup without ledger entries', () => {
    const payload = {
      app: 'my-hours',
      version: 1,
      exportedAt: '2026-08-16T00:00:00.000Z',
      records,
    }
    expect(parseBackupText(JSON.stringify(payload))).toEqual({
      records,
      entries: [],
      customCategories: [],
      workProfiles: [{ id: 'work-default', name: '默认工作', hourlyRate: 0 }],
      budgetTargets: { monthlyExpenseBudget: 0, monthlyIncomeGoal: 0 },
    })
  })

  it('rejects invalid backup text', () => {
    expect(() => parseBackupText('not json')).toThrow('不是有效 JSON')
    expect(() => parseBackupText('{"app":"other"}')).toThrow('格式不正确')
    expect(() =>
      parseBackupText(
        JSON.stringify({
          app: 'my-hours',
          version: 2,
          records: [{ date: 'bad', hours: 8, remark: '' }],
          entries: [],
        }),
      ),
    ).toThrow('包含无效工时记录')
    expect(() =>
      parseBackupText(
        JSON.stringify({
          app: 'my-hours',
          version: 3,
          records,
          entries: [],
          customCategories: [{ id: '', type: 'expense', name: '房租' }],
        }),
      ),
    ).toThrow('无效自定义分类')
  })

  it('builds a combined monthly overview CSV', () => {
    const csv = buildMonthOverviewCsv('2026-08', records, entries)
    expect(csv.startsWith('\uFEFF')).toBe(true)
    expect(csv).toContain('日期,星期,工时,备注,收入,支出')
    expect(csv).toContain('2026-08-01,星期六,8,普通班,5000,0')
    expect(csv).toContain('2026-08-02,星期日,8.5,"含,逗号",0,35.5')
    expect(csv).toContain('月总计,工作2天,16.5,,5000,35.5')
    expect(csv).toContain('月结余,,,,4964.5,')
    expect(csv).toContain('收入分类,工资,,,5000,')
    expect(csv).toContain('支出分类,餐饮,,,,35.5')
  })

  it('builds BOM CSV files for hours and ledger entries', () => {
    const hoursCsv = buildMonthCsv('2026-08', records)
    expect(hoursCsv.startsWith('\uFEFF')).toBe(true)
    expect(hoursCsv).toContain('2026-08-01,星期六,8,普通班')
    expect(hoursCsv).toContain('月总计,工作2天,16.5,')

    const ledgerCsv = buildLedgerCsv('2026-08', entries, records)
    expect(ledgerCsv.startsWith('\uFEFF')).toBe(true)
    expect(ledgerCsv).toContain('日期,类型,分类,金额,关联工时,备注')
    expect(ledgerCsv).toContain('2026-08-02,支出,餐饮,35.5,8.5小时,"午饭,饮料"')
    expect(ledgerCsv).toContain('月收入,5000')
    expect(ledgerCsv).toContain('月结余,4964.5')
  })

  it('neutralizes spreadsheet formula injection in exported cells', () => {
    const hostile = [
      { date: '2026-08-03', hours: 8, remark: '=HYPERLINK("http://evil","点我")' },
      { date: '2026-08-04', hours: 8, remark: '+SUM(1,2)' },
      { date: '2026-08-05', hours: 8, remark: '@cmd' },
      { date: '2026-08-06', hours: 8, remark: '-1+1' },
      { date: '2026-08-07', hours: 8, remark: '\tTAB开头' },
      { date: '2026-08-08', hours: 8, remark: '正常备注不受影响' },
    ]
    const csv = buildMonthCsv('2026-08', hostile)
    // 所有危险前缀都被单引号中和，Excel/WPS 打开时按纯文本处理
    expect(csv).toContain("'=HYPERLINK")
    expect(csv).toContain("'+SUM(1,2)")
    expect(csv).toContain("'@cmd")
    expect(csv).toContain("'-1+1")
    expect(csv).toContain("'\tTAB开头")
    // 普通文本不受影响
    expect(csv).toContain('正常备注不受影响')
  })
})
