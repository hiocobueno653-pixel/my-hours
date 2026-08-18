import { ChevronDown, FileDown, FileSpreadsheet, HardDrive, Moon, SlidersHorizontal, Sun } from 'lucide-react'
import { useState } from 'react'
import { currentMonthKey, parseMonthKey } from '../data/dates'
import { exportMonthOverviewCsv, exportMonthOverviewExcel } from '../services/exportService'
import { useAppStore } from '../store/useAppStore'
import { ConfirmDialog } from './ConfirmDialog'
import { BackupView } from './BackupView'
import { OverviewView } from './OverviewView'
import { WagePanel } from './WagePanel'
import { StatsPanels } from './StatsPanels'
import { BudgetPanel } from './BudgetPanel'
import { WorkManager } from './WorkManager'

export type ThemeMode = 'auto' | 'light' | 'dark'

interface MyViewProps {
  largeText: boolean
  onLargeTextChange: () => void
  onOpenDay: (date: string) => void
}

export function MyView({
  largeText,
  onLargeTextChange,
  onOpenDay,
}: MyViewProps) {
  const records = useAppStore((state) => state.records)
  const entries = useAppStore((state) => state.entries)
  const [yearMonth, setYearMonth] = useState(currentMonthKey)
  const [exportState, setExportState] = useState('')
  const [confirmClear, setConfirmClear] = useState(false)
  const [workManagerOpen, setWorkManagerOpen] = useState(false)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const year = parseMonthKey(yearMonth)?.year ?? new Date().getFullYear()

  const handleOverviewExport = async () => {
    setExportState('导出中')
    try {
      await exportMonthOverviewCsv(yearMonth, records, entries)
      setExportState('本月概览已导出')
    } catch {
      setExportState('导出失败')
    }
  }

  return (
    <div className="my-view page-enter">
      <header className="page-header">
        <h2>我的</h2>
        <p className="page-subtitle">看工资、管预算，把数据带走</p>
      </header>

      <section className="my-section" aria-label="本月总览">
        <div className="section-heading my-section-heading">
          <div>
            <h3>本月总览</h3>
            <span>点日期查看当天详情</span>
          </div>
          <span className="section-chip"><HardDrive size={14} /> 仅本机</span>
        </div>
        <OverviewView
          yearMonth={yearMonth}
          onYearMonthChange={setYearMonth}
          onOpenDay={onOpenDay}
          embedded
        />
      </section>

      <div className="my-section">
        <WagePanel
          yearMonth={yearMonth}
          onManageWork={() => setWorkManagerOpen(true)}
        />
      </div>
      <div className="my-section">
        <BudgetPanel yearMonth={yearMonth} />
      </div>
      <div className="my-section">
        <StatsPanels
          year={year}
          yearMonth={yearMonth}
          onSelectMonth={(selected) => setYearMonth(selected)}
        />
      </div>

      <section className="my-section backup-section" aria-label="数据备份">
        <div className="section-heading my-section-heading">
          <div>
            <h3>数据备份</h3>
            <span>导出文件后，可在系统分享面板选择云盘</span>
          </div>
          <div className="section-actions">
            <button type="button" className="button section-action" onClick={handleOverviewExport}>
              <FileDown size={17} />
              CSV
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
              <FileSpreadsheet size={17} />
              Excel
            </button>
          </div>
        </div>
        {exportState ? (
          <p className="status-line" role="status">
            {exportState}
          </p>
        ) : null}
        <BackupView compact />
      </section>

      <section className="my-section settings-section" aria-label="使用设置">
        <button
          type="button"
          className="section-heading my-section-heading collapsible-heading"
          onClick={() => setSettingsOpen((open) => !open)}
          aria-expanded={settingsOpen}
        >
          <span className="collapsible-title">
            <SlidersHorizontal size={17} color="var(--text-3)" aria-hidden="true" />
            <span>
              <strong>使用设置</strong>
              <small>大字模式、深色模式、数据清理</small>
            </span>
          </span>
          <ChevronDown size={18} className={settingsOpen ? 'chevron open' : 'chevron'} aria-hidden="true" />
        </button>
        {settingsOpen ? (
          <div className="settings-panel panel collapse-panel">
            <label className="inline-toggle">
              <input
                type="checkbox"
                checked={largeText}
                onChange={onLargeTextChange}
              />
              <span>大字模式</span>
            </label>
            <ThemeSetting />
            <button
              type="button"
              className="button danger full"
              onClick={() => setConfirmClear(true)}
            >
              清空全部数据
            </button>
          </div>
        ) : null}
      </section>

      {confirmClear ? (
        <ConfirmDialog
          title="清空全部数据？"
          message="会删除所有工时、账目、自定义分类、工作与预算，建议先保存备份。"
          confirmLabel="清空"
          danger
          onConfirm={() => {
            useAppStore.getState().clearAll()
            setConfirmClear(false)
          }}
          onCancel={() => setConfirmClear(false)}
        />
      ) : null}

      {workManagerOpen ? <WorkManager onClose={() => setWorkManagerOpen(false)} /> : null}
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
    const dark =
      mode === 'dark' ||
      (mode === 'auto' &&
        typeof window !== 'undefined' &&
        window.matchMedia('(prefers-color-scheme: dark)').matches)
    document.documentElement.dataset.theme = dark ? 'dark' : 'light'
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
