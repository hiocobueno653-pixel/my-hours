import { ChevronLeft, ChevronRight, Trash2, X } from 'lucide-react'
import { ConfirmDialog } from './ConfirmDialog'
import { useEffect, useMemo, useRef, useState } from 'react'
import {
  createLedgerEntryId,
  formatMoney,
  getAvailableLedgerCategories,
  parseAmountInput,
} from '../data/ledger'
import { formatDateLabel, todayISO, weekdayName } from '../data/dates'
import { formatHours, MAX_REMARK_LENGTH, parseHoursInput } from '../data/records'
import { DEFAULT_WORK_ID, getWorkById } from '../data/profiles'
import type { LedgerEntry, WorkDayRecord } from '../data/types'
import { useAppStore } from '../store/useAppStore'
import { haptic } from '../utils/haptics'
import { useModalLayer } from '../navigation/backNavigation'

const QUICK_HOURS = [0, 4, 8, 8.5, 10, 12]
const QUICK_INCOME_AMOUNTS = [100, 200, 500, 1000]

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
  useModalLayer(onClose)
  const saveDay = useAppStore((state) => state.saveDay)
  const deleteDay = useAppStore((state) => state.deleteDay)
  const saveLedgerEntry = useAppStore((state) => state.saveLedgerEntry)
  const deleteLedgerEntry = useAppStore((state) => state.deleteLedgerEntry)
  const customCategories = useAppStore((state) => state.customCategories)
  const entries = useAppStore((state) => state.entries)
  const workProfiles = useAppStore((state) => state.workProfiles)
  const [hours, setHours] = useState(record ? formatHours(record.hours) : '')
  const [remark, setRemark] = useState(record?.remark ?? '')
  const [workId, setWorkId] = useState(record?.workId ?? DEFAULT_WORK_ID)
  const [settled, setSettled] = useState(record?.settled ?? false)
  const [error, setError] = useState('')
  const [confirmDelete, setConfirmDelete] = useState(false)
  const linkedIncome = useMemo(
    () => entries.find((entry) => entry.type === 'income' && entry.workDate === date),
    [date, entries],
  )
  const [withIncome, setWithIncome] = useState(Boolean(linkedIncome))
  const [incomeAmount, setIncomeAmount] = useState(
    linkedIncome ? formatMoney(linkedIncome.amount) : '',
  )
  const [incomeCategory, setIncomeCategory] = useState(
    linkedIncome?.category ?? getAvailableLedgerCategories('income', customCategories)[0],
  )
  const incomeCategories = useMemo(
    () => getAvailableLedgerCategories('income', customCategories),
    [customCategories],
  )
  const incomeAmountRef = useRef<HTMLInputElement>(null)

  const selectedWork = getWorkById(workProfiles, workId)
  // 显示单价：编辑已有记录时沿用记录快照，新记录用当前工作时薪
  const effectiveRate = record?.rate ?? selectedWork?.hourlyRate ?? 0
  const parsedHours = parseHoursInput(hours)
  const hoursValue = parsedHours.ok ? parsedHours.hours : 0
  const dayPay = Math.round(hoursValue * effectiveRate * 100) / 100

  useEffect(() => {
    if (withIncome) incomeAmountRef.current?.focus()
  }, [withIncome])

  useEffect(() => {
    setHours(record ? formatHours(record.hours) : '')
    setRemark(record?.remark ?? '')
    setWorkId(record?.workId ?? DEFAULT_WORK_ID)
    setSettled(record?.settled ?? false)
    setWithIncome(Boolean(linkedIncome))
    setIncomeAmount(linkedIncome ? formatMoney(linkedIncome.amount) : '')
    setIncomeCategory(
      linkedIncome?.category ?? getAvailableLedgerCategories('income', customCategories)[0],
    )
    setError('')
  }, [
    date,
    record,
    linkedIncome,
    customCategories,
  ])

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
    // 编辑已有记录且未切换工作时，沿用原时薪快照（改工作时薪不回溯历史）
    const originalWorkId = record?.workId ?? DEFAULT_WORK_ID
    const preserveRate =
      record?.rate !== undefined && workId === originalWorkId
    const rate = preserveRate ? (record?.rate ?? 0) : (selectedWork?.hourlyRate ?? 0)
    const dayOptions = {
      workId,
      rate,
      settled,
    }
    if (withIncome) {
      const incomeResult = parseAmountInput(incomeAmount)
      if (!incomeResult.ok) {
        setError(incomeResult.error)
        return
      }
      saveDay(date, hoursResult.hours, remark.trim(), dayOptions)
      onSaved?.()
      saveLedgerEntry({
        id: linkedIncome?.id ?? createLedgerEntryId(),
        date,
        type: 'income',
        amount: incomeResult.amount,
        category: incomeCategory || linkedIncome?.category || incomeCategories[0],
        remark: remark.trim(),
        workDate: date,
      })
      onClose()
      return
    }
    saveDay(date, hoursResult.hours, remark.trim(), dayOptions)
    if (linkedIncome) deleteLedgerEntry(linkedIncome.id)
    onSaved?.()
    haptic()
    onClose()
  }

  const handleDelete = () => {
    if (!record) return
    setConfirmDelete(true)
  }

  const showWage = effectiveRate > 0

  return (
    <div className="sheet-backdrop" onClick={onClose}>
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
              onClick={() => onNextDay?.(date)}
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
              type="number"
              inputMode="decimal"
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
              }}
            >
              {value === 0 ? '休息' : formatHours(value)}
              {value !== 0 ? <small>小时</small> : null}
            </button>
          ))}
        </div>

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

        {showWage ? (
          <div className="wage-panel">
            <div className="wage-row">
              <span>时薪</span>
              <strong>¥{formatMoney(effectiveRate)}</strong>
              <span className="wage-op">×</span>
              <span>工时</span>
              <strong>{formatHours(hoursValue)}</strong>
            </div>
            <div className="wage-total">
              <span>本日工资</span>
              <strong>¥{formatMoney(dayPay)}</strong>
            </div>
            <label className="inline-toggle settle-toggle">
              <input
                type="checkbox"
                checked={settled}
                onChange={(event) => setSettled(event.target.checked)}
              />
              <span>已结算{settled ? ' ✓' : ''}（打工钱已到手）</span>
            </label>
          </div>
        ) : (
          <p className="field-note">
            尚未设置时薪，工资不会自动计算。到「我的」页设置后，这里会显示本日工资。
          </p>
        )}

        <label className="inline-toggle">
          <input
            type="checkbox"
            checked={withIncome}
            onChange={(event) => {
              setWithIncome(event.target.checked)
              setError('')
            }}
          />
          <span>同时记收入</span>
        </label>

        {withIncome ? (
          <div className="income-link-panel">
            <label className="field">
              <span className="field-label">收入金额</span>
              <span className="input-with-prefix">
                <span className="field-prefix">¥</span>
                <input
                  ref={incomeAmountRef}
                  type="number"
                  inputMode="decimal"
                  min="0.01"
                  step="0.01"
                  value={incomeAmount}
                  onChange={(event) => {
                    setIncomeAmount(event.target.value)
                    setError('')
                  }}
                  placeholder="0.00"
                />
              </span>
            </label>

            <div className="quick-amounts" aria-label="常用金额">
              {QUICK_INCOME_AMOUNTS.map((value) => (
                <button
                  type="button"
                  key={value}
                  className={`quick-amount${incomeAmount === String(value) ? ' active' : ''}`}
                  aria-pressed={incomeAmount === String(value)}
                  onClick={() => {
                    setIncomeAmount(String(value))
                    setError('')
                  }}
                >
                  ¥{value}
                </button>
              ))}
            </div>

            <label className="field">
              <span className="field-label">收入分类</span>
              <select
                value={incomeCategory}
                onChange={(event) => setIncomeCategory(event.target.value)}
              >
                {incomeCategories.map((item) => (
                  <option key={item} value={item}>
                    {item}
                  </option>
                ))}
              </select>
            </label>
          </div>
        ) : null}

        <label className="field">
          <span className="field-label">
            备注
            <span className="field-count">{remark.length}/{MAX_REMARK_LENGTH}</span>
          </span>
          <textarea
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
          ) : (
            <span />
          )}
          <button type="button" className="button primary" onClick={handleSave}>
            保存
          </button>
        </div>
      </section>

      {confirmDelete ? (
        <ConfirmDialog
          title="删除这天的记录？"
          message="删除后无法恢复。"
          confirmLabel="删除"
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
    </div>
  )
}
