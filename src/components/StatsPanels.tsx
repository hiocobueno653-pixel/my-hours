import { PieChart, TrendingUp } from 'lucide-react'
import { formatMoney } from '../data/ledger'
import { formatHours } from '../data/records'
import {
  getMonthCategoryTotals,
  getYearHoursTrend,
  getYearLedgerTrend,
  getYearSummary,
} from '../data/stats'
import { useAppStore } from '../store/useAppStore'
import { BarChart } from './charts/BarChart'
import { DonutChart } from './charts/DonutChart'

interface StatsPanelsProps {
  year: number
  yearMonth: string
  /** 点击趋势图中某个月份时回调（切换整套面板到该月） */
  onSelectMonth?: (yearMonth: string) => void
}

const CATEGORY_COLORS = [
  'var(--accent)',
  'var(--income)',
  'var(--expense)',
  'var(--gold)',
  '#8b5cf6',
  '#0891b2',
  '#db2777',
  '#65a30d',
  '#ea580c',
  '#64748b',
];

export function StatsPanels({ year, yearMonth, onSelectMonth }: StatsPanelsProps) {
  const records = useAppStore((state) => state.records)
  const entries = useAppStore((state) => state.entries)
  const hoursTrend = getYearHoursTrend(records, year)
  const ledgerTrend = getYearLedgerTrend(entries, year)
  const yearSummary = getYearSummary(records, entries, year)
  const categories = getMonthCategoryTotals(entries, yearMonth)
  const categoryTotal = categories.reduce((sum, item) => sum + item.total, 0)

  const monthLabel = (key: string) => `${Number(key.slice(5))}月`
  const hoursGroups = hoursTrend.map((point) => ({
    label: monthLabel(point.yearMonth),
    values: [{ value: point.hours, color: 'var(--accent)' }],
  }))
  const ledgerGroups = ledgerTrend.map((point) => ({
    label: monthLabel(point.yearMonth),
    values: [
      { value: point.income, color: 'var(--income)' },
      { value: point.expense, color: 'var(--expense)' },
    ],
  }))
  const hasLedger = yearSummary.totalIncome > 0 || yearSummary.totalExpense > 0
  const hasHours = yearSummary.totalHours > 0

  return (
    <section className="stats-panels" aria-label="年度统计">
      <div className="section-heading my-section-heading">
        <div>
          <h3>{year} 年度统计</h3>
          <span>全年趋势与分类占比</span>
        </div>
        <TrendingUp size={18} color="var(--text-3)" aria-hidden="true" />
      </div>
      <div className="stats-hero">
        <div className="stats-hero-item">
          <span>全年工时</span>
          <strong>{formatHours(yearSummary.totalHours)}<small> 小时</small></strong>
        </div>
        <div className="stats-hero-item">
          <span>全年工资</span>
          <strong>¥{formatMoney(yearSummary.totalPay)}</strong>
        </div>
        <div className="stats-hero-item">
          <span>收支结余</span>
          <strong
            className={yearSummary.totalIncome - yearSummary.totalExpense < 0 ? 'negative' : ''}
          >
            ¥{formatMoney(yearSummary.totalIncome - yearSummary.totalExpense)}
          </strong>
        </div>
      </div>

      {hasHours ? (
        <div className="chart-block">
          <div className="chart-block-head">
            <strong>每月工时</strong>
            <span>小时</span>
          </div>
          <BarChart
            data={hoursGroups}
            ariaLabel={`${year} 年每月工时柱状图，点击查看对应月份`}
            valueFormatter={(value) => `${formatHours(value)} 小时`}
            onGroupClick={onSelectMonth ? (index) => onSelectMonth(hoursTrend[index].yearMonth) : undefined}
          />
        </div>
      ) : (
        <p className="field-note chart-empty-note">全年还没有工时记录，记工时后这里会展示每月趋势。</p>
      )}

      {hasLedger ? (
        <div className="chart-block">
          <div className="chart-block-head">
            <strong>每月收支</strong>
            <span className="chart-legend">
              <span className="legend-dot income" />收入
              <span className="legend-dot expense" />支出
            </span>
          </div>
          <BarChart
            data={ledgerGroups}
            ariaLabel={`${year} 年每月收支柱状图，点击查看对应月份`}
            valueFormatter={(value) => `¥${formatMoney(value)}`}
            onGroupClick={onSelectMonth ? (index) => onSelectMonth(ledgerTrend[index].yearMonth) : undefined}
          />
        </div>
      ) : null}

      {categories.length > 0 ? (
        <div className="chart-block category-chart-block">
          <div className="chart-block-head">
            <strong>本月分类占比</strong>
            <PieChart size={15} color="var(--text-3)" aria-hidden="true" />
          </div>
          <div className="category-chart-layout">
            <DonutChart
              segments={categories.map((item, index) => ({
                label: item.name,
                value: item.total,
                color: CATEGORY_COLORS[index % CATEGORY_COLORS.length],
              }))}
              centerLabel="当月合计"
              centerValue={`¥${formatMoney(categoryTotal)}`}
            />
            <ul className="category-legend-list">
              {categories.slice(0, 7).map((item, index) => (
                <li key={`${item.type}-${item.name}`}>
                  <span
                    className="legend-dot"
                    style={{ backgroundColor: CATEGORY_COLORS[index % CATEGORY_COLORS.length] }}
                  />
                  <span className="category-legend-name">{item.name}</span>
                  <strong>¥{formatMoney(item.total)}</strong>
                </li>
              ))}
            </ul>
          </div>
        </div>
      ) : null}
    </section>
  )
}
