import { BadgeCheck, CheckCheck, Wrench } from 'lucide-react'
import { formatMoney } from '../data/ledger'
import { getMonthWorkBreakdown } from '../data/stats'
import { formatHours, getMonthPay, getSettlementSummary } from '../data/records'
import { useAppStore } from '../store/useAppStore'
import { ProgressBar } from './charts/ProgressBar'

interface WagePanelProps {
  yearMonth: string
  onManageWork: () => void
}

export function WagePanel({ yearMonth, onManageWork }: WagePanelProps) {
  const records = useAppStore((state) => state.records)
  const workProfiles = useAppStore((state) => state.workProfiles)
  const settleMonth = useAppStore((state) => state.settleMonth)
  const monthPay = getMonthPay(records, yearMonth)
  const settlement = getSettlementSummary(records, yearMonth)
  const rows = getMonthWorkBreakdown(records, workProfiles, yearMonth)
  const hasWage = monthPay > 0

  return (
    <section className="panel wage-panel" aria-label="本月工资">
      <div className="section-heading my-section-heading">
        <div>
          <h3>本月工资</h3>
          <span>工时 × 时薪自动计算，可标记结算</span>
        </div>
        <button type="button" className="icon-button" onClick={onManageWork} aria-label="管理工作" title="管理工作">
          <Wrench size={18} />
        </button>
      </div>
      <div className="wage-hero">
        <div className="wage-hero-value">
          <span>应得工资</span>
          <strong>¥{formatMoney(monthPay)}</strong>
        </div>
        {hasWage ? (
          <div className="wage-hero-settle">
            <span>已结算</span>
            <strong>¥{formatMoney(settlement.settled)}</strong>
            <span className="category-kind">{settlement.settledCount}/{settlement.settledCount + settlement.pendingCount} 笔</span>
          </div>
        ) : null}
      </div>

      {hasWage ? (
        <>
          <ProgressBar
            value={settlement.settled}
            max={settlement.total}
            tone="gold"
            height={8}
          />
          <div className="wage-actions">
            <button
              type="button"
              className="button"
              onClick={() => settleMonth(yearMonth, true)}
            >
              <CheckCheck size={16} />
              全部标记已结算
            </button>
            {settlement.settled > 0 ? (
              <button
                type="button"
                className="button ghost"
                onClick={() => settleMonth(yearMonth, false)}
              >
                撤销结算
              </button>
            ) : null}
          </div>
        </>
      ) : (
        <p className="field-note">
          本月还没有可计算的工资。给工作设置时薪后，记工时即自动计算。
        </p>
      )}

      {rows.length > 0 ? (
        <div className="work-breakdown">
          {rows.map((row) => (
            <div className="work-breakdown-row" key={row.workId}>
              <span className="work-breakdown-name">{row.name}</span>
              <span className="work-breakdown-hours">{formatHours(row.hours)} 时</span>
              <strong className="work-breakdown-pay">¥{formatMoney(row.pay)}</strong>
            </div>
          ))}
        </div>
      ) : (
        <div className="wage-empty">
          <BadgeCheck size={20} />
          <span>本月的工时记录会显示在这里</span>
        </div>
      )}
    </section>
  )
}
