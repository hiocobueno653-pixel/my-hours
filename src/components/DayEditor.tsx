import { ChevronLeft, ChevronRight, Trash2, X } from 'lucide-react'
import { ConfirmDialog } from './ConfirmDialog'
import { WorkManager } from './WorkManager'
import { useEffect, useMemo, useRef, useState } from 'react'
import { formatMoney } from '../data/ledger'
import {
  formatDateLabel,
  shiftDate,
  todayISO,
  weekdayName,
} from '../data/dates'
import { formatHours, getEffectiveRate, getMonthPay, getMonthSummary, MAX_FIXED_PAY, MAX_REMARK_LENGTH, parseHoursInput } from '../data/records'
import { DEFAULT_WORK_ID, getWorkById } from '../data/profiles'
import type { LedgerEntry, WorkDayRecord } from '../data/types'
import { useAppStore } from '../store/useAppStore'
import { isWageEntryForDate } from '../data/wageEntries'
import { haptic } from '../utils/haptics'
import { useModalLayer } from '../navigation/backNavigation'

// 「只记工时」变体（VITE_HOURS_ONLY=1 构建）：隐藏工作/时薪/工资/结算，只记工时
const HOURS_ONLY = import.meta.env.VITE_HOURS_ONLY === '1'

const QUICK_HOURS = [0, 4, 6, 8, 8.5, 10, 12]

interface DayEditorProps {
  date: string
  record?: WorkDayRecord
  onClose: () => void
  onSaved?: () => void
  onDeleted?: (record: WorkDayRecord, linkedIncome?: LedgerEntry) => void
  onPreviousDay?: (date: string) => void
  onNextDay?: (date: string) => void
}

export function DayEditor({ date, record, onClose, onSaved, onDeleted, onPreviousDay, onNextDay }: DayEditorProps) {
  const { containerRef, onKeyDown } = useModalLayer(onClose)
  const saveDay = useAppStore((state) => state.saveDay)
  const deleteDay = useAppStore((state) => state.deleteDay)
  const deleteLedgerEntry = useAppStore((state) => state.deleteLedgerEntry)
  const entries = useAppStore((state) => state.entries)
  const records = useAppStore((state) => state.records)
  const workProfiles = useAppStore((state) => state.workProfiles)
  const [hours, setHours] = useState(record ? formatHours(record.hours) : '')
  const [remark, setRemark] = useState(record?.remark ?? '')
  const [workId, setWorkId] = useState(record?.workId ?? DEFAULT_WORK_ID)
  const [settled, setSettled] = useState(record?.settled ?? false)
  const [error, setError] = useState('')
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [workManagerOpen, setWorkManagerOpen] = useState(false)
  const remarkInputRef = useRef<HTMLTextAreaElement>(null)
  const [customPay, setCustomPay] = useState('')
  // 关联收入与旧版手工工资：单次遍历 entries 找齐
  const { linkedIncome, legacyLinkedIncome } = useMemo(() => {
    let linkedIncome: LedgerEntry | undefined
    let legacyLinkedIncome: LedgerEntry | undefined
    for (const entry of entries) {
      if (entry.type === 'income' && entry.workDate === date) {
        if (!linkedIncome) linkedIncome = entry
        if (!legacyLinkedIncome && !isWageEntryForDate(entry, date)) {
          legacyLinkedIncome = entry
        }
        if (linkedIncome && legacyLinkedIncome) break
      }
    }
    return { linkedIncome, legacyLinkedIncome }
  }, [date, entries])
  const hoursInputRef = useRef<HTMLInputElement>(null)

  // 弹窗滑入动画结束后再聚焦工时输入框，避免键盘弹出与动画竞争导致屏幕闪烁
  useEffect(() => {
    const timer = window.setTimeout(() => {
      hoursInputRef.current?.focus()
    }, 380)
    return () => window.clearTimeout(timer)
  }, [])

  const selectedWork = getWorkById(workProfiles, workId)
  // 显示单价：与统计/详情页同一口径（快照 >0 优先，否则当前工作时薪）
  const effectiveRate = getEffectiveRate({ rate: record?.rate, workId }, workProfiles)
  const customFixedPay =
    record?.fixedPay !== undefined && Number.isFinite(record.fixedPay) && record.fixedPay > 0
      ? formatMoney(record.fixedPay)
      : ''
  const parsedHours = parseHoursInput(hours)
  const hoursValue = parsedHours.ok ? parsedHours.hours : 0
  const currentFixedPay =
    customFixedPay !== '' ? Number(customFixedPay) : customPay !== '' ? Number(customPay) : 0
  const dayPay =
    // 固定日薪留空/为 0 时回退自动计算（工时 × 有效时薪），与保存口径一致
    Number.isFinite(currentFixedPay) && currentFixedPay > 0
      ? Math.round(currentFixedPay * 100) / 100
      : Math.round(hoursValue * effectiveRate * 100) / 100
  const monthKey = date.slice(0, 7)
  const monthSummary = getMonthSummary(records, monthKey)
  const monthPay = getMonthPay(records, monthKey, workProfiles)

  useEffect(() => {
    setHours(record ? formatHours(record.hours) : '')
    setRemark(record?.remark ?? '')
    setWorkId(record?.workId ?? DEFAULT_WORK_ID)
    setSettled(record?.settled ?? false)
    setCustomPay(
      record?.fixedPay !== undefined && Number.isFinite(record.fixedPay) && record.fixedPay > 0
        ? formatMoney(record.fixedPay)
        : '',
    )
    setError('')
  }, [date, record])

  const weekday = weekdayName(new Date(`${date}T00:00:00`).getDay())
  const title =
    date === todayISO()
      ? `今天 · 周${weekday}`
      : `${formatDateLabel(date)} · 周${weekday}`

  const handleSave = () => {
    const hoursResult = parseHoursInput(hours)
    if (!hoursResult.ok) {
      setError(hoursResult.error)
      return
    }
    if (date > todayISO()) {
      setError('不能记录未来日期')
      return
    }
    // 编辑已有记录且未切换工作时，沿用原时薪快照（改工作时薪不回溯历史）
    const originalWorkId = record?.workId ?? DEFAULT_WORK_ID
    const preserveRate =
      record?.rate !== undefined && workId === originalWorkId
    let rate = preserveRate ? (record?.rate ?? 0) : (selectedWork?.hourlyRate ?? 0)
    // 自定义当日工资：格式与范围校验
    let fixedPay: number | undefined
    if (customPay.trim() !== '') {
      const trimmed = customPay.trim()
      if (!/^(?:\d+(?:\.\d{1,2})?|\.\d{1,2})$/.test(trimmed)) {
        setError('当日工资最多两位小数')
        return
      }
      const val = Number(trimmed)
      if (!Number.isFinite(val) || val < 0 || val > MAX_FIXED_PAY) {
        setError('当日工资超出有效范围')
        return
      }
      if (val > 0) fixedPay = Math.round(val * 100) / 100
    }
    const effectivePay =
      fixedPay !== undefined
        ? fixedPay
        : Math.round(hoursResult.hours * rate * 100) / 100
    saveDay(
      date,
      hoursResult.hours,
      remark.trim(),
      // 「只记工时」变体只保存工时与备注，不关联工作/时薪/工资状态
      HOURS_ONLY
        ? undefined
        : {
            workId,
            rate,
            fixedPay,
            settled: effectivePay > 0 ? settled : false,
          },
    )
    // 旧数据兼容：之前通过"同时记收入"创建的关联收入，保存工时时一并移除
    if (legacyLinkedIncome) deleteLedgerEntry(legacyLinkedIncome.id)
    onSaved?.()
    haptic()
    onClose()
  }

  const handleDelete = () => {
    if (!record) return
    setConfirmDelete(true)
  }

  const goNextDay = () => {
    const next = shiftDate(date, 1)
    if (next > todayISO()) {
      setError('不能记录未来日期')
      return
    }
    onNextDay?.(next)
  }

  return (
    <div className="sheet-backdrop" ref={containerRef} onClick={onClose} onKeyDown={onKeyDown}>
      <section
        className="day-sheet"
        role="dialog"
        aria-modal="true"
        aria-label={`${date} 工时`}
        onClick={(event) => event.stopPropagation()}
      >
        <div className="sheet-header">
          <div className="day-nav">
            <button
              type="button"
              className="icon-button small"
              onClick={() => onPreviousDay?.(date)}
              aria-label="前一天"
            >
              <ChevronLeft size={20} />
            </button>
            <h2>{title}</h2>
            <button
              type="button"
              className="icon-button small"
              onClick={goNextDay}
              disabled={date >= todayISO()}
              aria-label="后一天"
            >
              <ChevronRight size={20} />
            </button>
          </div>
          <button type="button" className="icon-button" onClick={onClose} aria-label="关闭">
            <X size={20} />
          </button>
        </div>

        <label className="field">
          <span className="field-label">工时</span>
          <span className="input-with-suffix">
            <input
              ref={hoursInputRef}
              type="number"
              inputMode="decimal"
              className="numeric-hero-input"
              min="0"
              max="24"
              step="0.01"
              value={hours}
              onChange={(event) => {
                setHours(event.target.value)
                setError('')
              }}
              placeholder="8.5"
            />
            <span className="field-suffix">小时</span>
          </span>
        </label>
        {error ? <p className="error-text">{error}</p> : null}

        <div className="quick-hours" aria-label="常用工时">
          {QUICK_HOURS.map((value) => (
            <button
              type="button"
              key={value}
              className={`quick-hour${hours === formatHours(value) ? ' active' : ''}`}
              aria-pressed={hours === formatHours(value)}
              onClick={() => {
                setHours(formatHours(value))
                setError('')
                // 点选快捷工时后直接进入备注，形成「选时长 → 写备注 → 保存」流
                remarkInputRef.current?.focus()
              }}
            >
              {value === 0 ? '休息' : formatHours(value)}
              {value !== 0 ? <small>小时</small> : null}
            </button>
          ))}
        </div>

        {HOURS_ONLY ? null : (
        <>
        <div className="field">
          <span className="field-label">工作</span>
          <select
            value={workId}
            onChange={(event) => setWorkId(event.target.value)}
            aria-label="工作"
          >
            {workProfiles.map((profile) => (
              <option key={profile.id} value={profile.id}>
                {profile.name}
                {profile.hourlyRate > 0 ? ` · ¥${formatMoney(profile.hourlyRate)}/时` : ''}
              </option>
            ))}
          </select>
        </div>

        <div className="wage-panel">
            <div className="wage-row">
              <span>时薪</span>
              <strong>¥{formatMoney(effectiveRate)}</strong>
              <span className="wage-op">×</span>
              <span>工时</span>
              <strong>{formatHours(hoursValue)}</strong>
            </div>
            <label className="field">
              <span className="field-label">当日工资（可选，留空自动计算）</span>
              <span className="input-with-prefix">
                <span className="field-prefix">¥</span>
                <input
                  type="number"
                  inputMode="decimal"
                min="0"
                step="0.01"
                value={customPay}
                onChange={(event) => {
                  setCustomPay(event.target.value)
                  setError('')
                }}
                placeholder={dayPay > 0 ? formatMoney(dayPay) : '0.00'}
              />
              </span>
            </label>
            <div className="wage-total">
              <span>本日工资</span>
              <strong>¥{formatMoney(dayPay)}</strong>
            </div>
          <label className="inline-toggle settle-toggle">
            <input
              type="checkbox"
              checked={settled}
              onChange={(event) => setSettled(event.target.checked)}
              disabled={dayPay <= 0}
            />
            <span>已结算{settled ? ' ✓' : ''}（打工钱已到手）</span>
          </label>
          </div>
        </>
        )}

        {monthSummary.totalHours > 0 ? (
          <p className="month-cumulative">
            <span>本月累计</span>
            <strong>{formatHours(monthSummary.totalHours)} 小时</strong>
            {!HOURS_ONLY && monthPay > 0 ? (
              <>
                <span className="month-cumulative-sep">·</span>
                <strong className="month-cumulative-pay">¥{formatMoney(monthPay)}</strong>
              </>
            ) : null}
          </p>
        ) : null}

        <label className="field">
          <span className="field-label">
            备注
            <span className="field-count">{remark.length}/{MAX_REMARK_LENGTH}</span>
          </span>
          <textarea
            ref={remarkInputRef}
            value={remark}
            maxLength={MAX_REMARK_LENGTH}
            onChange={(event) => setRemark(event.target.value)}
            rows={3}
          />
        </label>

        <div className="sheet-actions">
          {record ? (
            <button type="button" className="button danger" onClick={handleDelete}>
              <Trash2 size={18} />
              删除
            </button>
          ) : null}
          <button type="button" className="button primary" onClick={handleSave}>
            保存
          </button>
        </div>
      </section>

      {confirmDelete ? (
        <ConfirmDialog
          title="删除这天的记录？"
          message="删除后无法恢复。"
          confirmLabel="确认"
          danger
          onConfirm={() => {
            if (!record) return
            deleteDay(date)
            if (linkedIncome) deleteLedgerEntry(linkedIncome.id)
            onDeleted?.(record, linkedIncome)
            haptic([20, 40, 20])
            onClose()
          }}
          onCancel={() => setConfirmDelete(false)}
        />
      ) : null}

      {workManagerOpen ? (
        <WorkManager onClose={() => setWorkManagerOpen(false)} />
      ) : null}
    </div>
  )
}
