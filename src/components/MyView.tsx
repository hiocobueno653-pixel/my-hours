import { ChevronLeft, ChevronRight, FileDown, FileSpreadsheet, HardDrive, Moon, Sun } from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { currentMonthKey, formatMonthLabel, parseMonthKey, shiftMonth } from '../data/dates'
import { exportMonthOverviewCsv, exportMonthOverviewExcel } from '../services/exportService'
import { formatMoney, getLedgerMonthSummary } from '../data/ledger'
import { formatHours, getMonthDelta, getMonthSummary, getSettlementSummary } from '../data/records'
import { useAppStore } from '../store/useAppStore'
import { applyThemeMode, type ThemeMode } from '../utils/theme'
import { useBackDismiss } from '../navigation/backNavigation'
import { ConfirmDialog } from './ConfirmDialog'
import { BackupView } from './BackupView'
import { WagePanel } from './WagePanel'
import { StatsPanels } from './StatsPanels'
import { BudgetPanel } from './BudgetPanel'
import { WorkManager } from './WorkManager'
import { MonthPicker } from './MonthPicker'

// 「只记工时」变体（VITE_HOURS_ONLY=1 构建）：隐藏预算、账目收入/结余、分类占比
const HOURS_ONLY = import.meta.env.VITE_HOURS_ONLY === '1'


interface MyViewProps {
  largeText: boolean
  onLargeTextChange: () => void
  /** 二级页面（年度统计/备份/设置）打开/关闭时通知父层，用于隐藏底部导航栏 */
  onSubPageChange?: (open: boolean) => void
}

const SUBPAGE_BACK_THRESHOLD = 72 // 右滑超过 72px 触发返回（可预测性动画的跟手阈值）

export function MyView({
  largeText,
  onLargeTextChange,
  onSubPageChange,
}: MyViewProps) {
  const records = useAppStore((state) => state.records)
  const entries = useAppStore((state) => state.entries)
  const workProfiles = useAppStore((state) => state.workProfiles)
  const budgetTargets = useAppStore((state) => state.budgetTargets)
  const [yearMonth, setYearMonth] = useState(currentMonthKey)
  const [monthPickerOpen, setMonthPickerOpen] = useState(false)
  const [exportState, setExportState] = useState('')
  const [confirmClear, setConfirmClear] = useState(false)
  const [workManagerOpen, setWorkManagerOpen] = useState(false)
  const [subPage, setSubPage] = useState<'stats' | 'backup' | null>(null)
  const [dragX, setDragX] = useState(0)
  const [dragging, setDragging] = useState(false)
  const dragStartRef = useRef<{ x: number; y: number } | null>(null)
  const dragOffsetRef = useRef(0)
  const year = parseMonthKey(yearMonth)?.year ?? new Date().getFullYear()
  const monthSummary = useMemo(
    () => getMonthSummary(records, yearMonth),
    [records, yearMonth],
  )
  const settlement = useMemo(
    () => getSettlementSummary(records, yearMonth, workProfiles),
    [records, yearMonth, workProfiles],
  )
  const monthDelta = useMemo(
    () => getMonthDelta(records, yearMonth, shiftMonth),
    [records, yearMonth],
  )
  const ledgerSummary = useMemo(
    () => getLedgerMonthSummary(entries, yearMonth),
    [entries, yearMonth],
  )
  const hasBudget =
    budgetTargets.monthlyExpenseBudget > 0 || budgetTargets.monthlyIncomeGoal > 0

  const handleOverviewExport = async () => {
    setExportState('导出中')
    try {
      await exportMonthOverviewCsv(yearMonth, records, entries)
      setExportState('本月概览已导出')
    } catch {
      setExportState('导出失败')
    }
  }

  // 二级页面打开时隐藏底部导航栏并回到顶部（避免保留上次滚动位置），返回时恢复
  useEffect(() => {
    onSubPageChange?.(subPage !== null)
    if (subPage !== null) window.scrollTo(0, 0)
  }, [subPage, onSubPageChange])

  const closeSubPage = () => setSubPage(null)

  // 二级页面打开时，Android 返回键关闭二级页而不是切到首页
  useBackDismiss(closeSubPage, subPage !== null)

  // 右滑跟手返回（可预测性动画）：二级页面向右拖动时页面跟随位移，
  // 松手超过阈值则滑出返回，否则回弹——让用户预见到返回的目标页面。
  const onTouchStart = (event: React.TouchEvent) => {
    if (subPage === null) return
    const touch = event.touches[0]
    dragStartRef.current = { x: touch.clientX, y: touch.clientY }
    dragOffsetRef.current = 0
    setDragging(true)
  }

  const onTouchMove = (event: React.TouchEvent) => {
    if (subPage === null || !dragStartRef.current) return
    const touch = event.touches[0]
    const dx = touch.clientX - dragStartRef.current.x
    const dy = touch.clientY - dragStartRef.current.y
    // 仅右滑且横向为主时跟手
    if (dx > 0 && Math.abs(dx) > Math.abs(dy) * 1.5) {
      dragOffsetRef.current = Math.min(dx, 220)
      setDragX(dragOffsetRef.current)
    }
  }

  const onTouchEnd = () => {
    if (subPage === null || !dragStartRef.current) return
    dragStartRef.current = null
    setDragging(false)
    if (dragOffsetRef.current >= SUBPAGE_BACK_THRESHOLD) {
      setSubPage(null)
    }
    setDragX(0)
  }

  // 触摸被系统中断（来电/下拉通知）时也要复位，避免 transform 卡住
  const onTouchCancel = () => {
    if (subPage === null) return
    dragStartRef.current = null
    setDragging(false)
    setDragX(0)
  }

  const subpageClass = `subpage${dragging ? ' dragging' : ''}`
  const subpageStyle = dragging && dragX > 0 ? { transform: `translateX(${dragX}px)` } : undefined

  return (
    <div
      className={`my-view page-enter${subPage !== null ? ' subpage-open' : ''}${HOURS_ONLY ? ' hours-only' : ''}`}
      onTouchStart={onTouchStart}
      onTouchMove={onTouchMove}
      onTouchEnd={onTouchEnd}
      onTouchCancel={onTouchCancel}
    >
      {subPage === 'stats' ? (
        <div className={subpageClass} style={subpageStyle}>
          <header className="subpage-header">
            <button type="button" className="icon-button" onClick={closeSubPage} aria-label="返回">
              <ChevronLeft size={20} />
            </button>
            <h2>年度统计</h2>
            <span className="subpage-header-spacer" />
          </header>
          <div className="subpage-content">
            <StatsPanels year={year} yearMonth={yearMonth} onSelectMonth={setYearMonth} />
          </div>
        </div>
      ) : null}

      {subPage === 'backup' ? (
        <div className={subpageClass} style={subpageStyle}>
          <header className="subpage-header">
            <button type="button" className="icon-button" onClick={closeSubPage} aria-label="返回">
              <ChevronLeft size={20} />
            </button>
            <h2>数据与设置</h2>
            <span className="subpage-header-spacer" />
          </header>
          <div className="subpage-content">
            <BackupView />
            <section className="settings-panel panel">
              <div className="section-heading">
                <h3>导出本月概览</h3>
              </div>
              <div className="section-actions backup-export-actions">
                <button type="button" className="button section-action" onClick={handleOverviewExport}>
                  <FileDown size={17} /> CSV
                </button>
                <button
                  type="button"
                  className="button section-action"
                  onClick={async () => {
                    setExportState('导出中')
                    try {
                      await exportMonthOverviewExcel(yearMonth, records, entries)
                      setExportState('本月概览已导出 Excel')
                    } catch {
                      setExportState('导出失败')
                    }
                  }}
                >
                  <FileSpreadsheet size={17} /> Excel
                </button>
              </div>
              {exportState ? <p className="status-line" role="status">{exportState}</p> : null}
            </section>
            <section className="settings-panel panel">
              <div className="section-heading">
                <h3>显示</h3>
              </div>
              <label className="inline-toggle">
                <input type="checkbox" checked={largeText} onChange={onLargeTextChange} />
                <span>大字模式</span>
              </label>
              <ThemeSetting />
            </section>
            <section className="settings-panel panel">
              <div className="section-heading">
                <h3>危险操作</h3>
              </div>
              <button type="button" className="button danger full" onClick={() => setConfirmClear(true)}>
                清空全部数据
              </button>
            </section>
          </div>
        </div>
      ) : null}

      {subPage === null ? (
      <>
      <header className="mine-page-header">
        <div className="mine-heading-row">
          <div className="screen-header-copy">
            <span className="screen-kicker">个人数据</span>
            <h1>我的</h1>
          </div>
          <div className="header-tool-group">
            <span className="local-only-mark"><HardDrive size={14} /> {hasBudget ? '已备份' : '仅本机'}</span>
            <div className="inline-month-nav" aria-label="月份切换">
              <button type="button" className="month-nav-button" onClick={() => setYearMonth((current) => shiftMonth(current, -1))} aria-label="上个月">
                <ChevronLeft size={19} />
              </button>
              <h2
                className="month-nav-label"
                tabIndex={0}
                title="选择月份"
                onClick={() => setMonthPickerOpen(true)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault()
                    setMonthPickerOpen(true)
                  }
                }}
              >
                {formatMonthLabel(yearMonth)}
              </h2>
              <button type="button" className="month-nav-button" onClick={() => setYearMonth((current) => shiftMonth(current, 1))} aria-label="下个月">
                <ChevronRight size={19} />
              </button>
            </div>
          </div>
        </div>
      </header>

      <section className="mine-summary" aria-label="本月概览">
        <div className="mine-summary-hours">
          <span>本月工时</span>
          <strong>{formatHours(monthSummary.totalHours)}<small> 小时</small></strong>
          <small>{monthSummary.workDays} 个工作日</small>
          {monthDelta ? (
            <span className={`hero-delta${monthDelta.delta >= 0 ? ' up' : ' down'}`}>
              {monthDelta.delta >= 0 ? '↑' : '↓'} 比上月 {monthDelta.delta >= 0 ? '+' : ''}{formatHours(monthDelta.delta)} 小时（{monthDelta.delta >= 0 ? '+' : ''}{monthDelta.percent}%）
            </span>
          ) : null}
        </div>
        {HOURS_ONLY ? null : (
        <dl className={`mine-summary-money${HOURS_ONLY ? ' hours-only' : ''}`}>
          <div className="pay">
            <dt>待结算</dt>
            <dd>¥{formatMoney(settlement.pending)}</dd>
            {settlement.total > 0 ? (
              <small>已结算 ¥{formatMoney(settlement.settled)}</small>
            ) : monthSummary.workDays > 0 ? (
              <small className="setup-wage-hint">未设时薪</small>
            ) : null}
          </div>
          <div className="income">
            <dt>账目收入</dt>
            <dd>¥{formatMoney(ledgerSummary.income)}</dd>
          </div>
          <div className={ledgerSummary.balance < 0 ? 'expense' : 'pay'}>
            <dt>本月结余</dt>
            <dd>
              {ledgerSummary.balance < 0 ? '-' : ''}¥{formatMoney(Math.abs(ledgerSummary.balance))}
            </dd>
          </div>
        </dl>
        )}
      </section>

      {HOURS_ONLY ? null : (
      <section className="my-section">
        <WagePanel yearMonth={yearMonth} onManageWork={() => setWorkManagerOpen(true)} />
      </section>
      )}
      {HOURS_ONLY ? null : (
      <section className="my-section">
        <BudgetPanel yearMonth={yearMonth} />
      </section>
      )}

      <section className="my-section my-nav-group" aria-label="更多功能">
        <button
          type="button"
          className="my-nav-row"
          onClick={() => setSubPage('stats')}
        >
          <span className="my-nav-row-copy">
            <strong>年度统计</strong>
            <small>{HOURS_ONLY ? '工时趋势' : '趋势图与分类占比'}</small>
          </span>
          <ChevronRight size={18} className="my-nav-arrow" aria-hidden="true" />
        </button>
        <button
          type="button"
          className="my-nav-row"
          onClick={() => setSubPage('backup')}
        >
          <span className="my-nav-row-copy">
            <strong>数据与设置</strong>
            <small>备份恢复、导出、外观与数据清理</small>
          </span>
          <ChevronRight size={18} className="my-nav-arrow" aria-hidden="true" />
        </button>
      </section>
      </>
      ) : null}

      {confirmClear ? (
        <ConfirmDialog
          title="清空全部数据？"
          message="会删除所有工时、账目、自定义分类、工作与预算，建议先保存备份。"
          confirmLabel="确认"
          danger
          onConfirm={() => {
            useAppStore.getState().clearAll()
            setConfirmClear(false)
          }}
          onCancel={() => setConfirmClear(false)}
        />
      ) : null}

      {workManagerOpen ? <WorkManager onClose={() => setWorkManagerOpen(false)} /> : null}

      {monthPickerOpen ? (
        <MonthPicker
          value={yearMonth}
          onSelect={(next) => {
            setYearMonth(next)
            setMonthPickerOpen(false)
          }}
          onClose={() => setMonthPickerOpen(false)}
        />
      ) : null}
    </div>
  )
}

export function ThemeSetting() {
  const [theme, setThemeState] = useState<ThemeMode>(() => {
    try {
      const stored = window.localStorage.getItem('my-hours.theme')
      if (stored === 'light' || stored === 'dark') return stored
    } catch {
      // 存储不可用时使用跟随系统
    }
    return 'auto'
  })

  const applyTheme = (mode: ThemeMode) => {
    setThemeState(mode)
    try {
      window.localStorage.setItem('my-hours.theme', mode)
    } catch {
      // 隐私模式下忽略
    }
    applyThemeMode(mode)
  }

  const options: { value: ThemeMode; label: string }[] = [
    { value: 'auto', label: '跟随系统' },
    { value: 'light', label: '浅色' },
    { value: 'dark', label: '深色' },
  ]

  return (
    <div className="theme-setting">
      <div className="theme-setting-label">
        <Moon size={16} />
        <span>深色模式</span>
      </div>
      <div className="segmented theme-segmented" aria-label="深色模式">
        {options.map((option) => (
          <button
            type="button"
            key={option.value}
            className={theme === option.value ? "segment active" : 'segment'}
            aria-pressed={theme === option.value}
            onClick={() => applyTheme(option.value)}
          >
            {option.value === 'dark' ? <Moon size={14} /> : option.value === 'light' ? <Sun size={14} /> : null}
            {option.label}
          </button>
        ))}
      </div>
    </div>
  )
}
