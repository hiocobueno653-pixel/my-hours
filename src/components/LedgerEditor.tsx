import { Tags, Trash2, X } from 'lucide-react'
import { useMemo, useState } from 'react'
import { todayISO } from '../data/dates'
import {
  createLedgerEntryId,
  formatMoney,
  getAvailableLedgerCategories,
  MAX_LEDGER_REMARK_LENGTH,
  parseAmountInput,
} from '../data/ledger'
import { formatHours } from '../data/records'
import type { LedgerEntry, LedgerType } from '../data/types'
import { useAppStore } from '../store/useAppStore'
import { haptic } from '../utils/haptics'
import { useModalLayer } from '../navigation/backNavigation'
import { CategoryManager } from './CategoryManager'
import { ConfirmDialog } from './ConfirmDialog'

interface LedgerEditorProps {
  entry?: LedgerEntry
  onClose: () => void
  onSaved?: () => void
  onDeleted?: (entry: LedgerEntry) => void
}

export function LedgerEditor({ entry, onClose, onSaved, onDeleted }: LedgerEditorProps) {
  useModalLayer(onClose)
  const records = useAppStore((state) => state.records)
  const customCategories = useAppStore((state) => state.customCategories)
  const saveLedgerEntry = useAppStore((state) => state.saveLedgerEntry)
  const deleteLedgerEntry = useAppStore((state) => state.deleteLedgerEntry)
  const [type, setType] = useState<LedgerType>(entry?.type ?? 'expense')
  const [date, setDate] = useState(entry?.date ?? todayISO())
  const [amount, setAmount] = useState(entry ? formatMoney(entry.amount) : '')
  const [category, setCategory] = useState(
    entry?.category ??
      getAvailableLedgerCategories('expense', customCategories)[0],
  )
  const [workDate, setWorkDate] = useState(entry?.workDate ?? '')
  const [remark, setRemark] = useState(entry?.remark ?? '')
  const [error, setError] = useState('')
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [managerOpen, setManagerOpen] = useState(false)

  const categoryOptions = useMemo(
    () => getAvailableLedgerCategories(type, customCategories, entry?.category),
    [customCategories, entry?.category, type],
  )
  const sortedRecords = useMemo(
    () => [...records].sort((a, b) => a.date.localeCompare(b.date)),
    [records],
  )

  const handleTypeChange = (nextType: LedgerType) => {
    setType(nextType)
    setCategory(getAvailableLedgerCategories(nextType, customCategories)[0])
    setError('')
  }

  const handleSave = () => {
    const result = parseAmountInput(amount)
    if (!result.ok) {
      setError(result.error)
      return
    }
    if (!date) {
      setError('请选择日期')
      return
    }
    saveLedgerEntry({
      id: entry?.id ?? createLedgerEntryId(),
      date,
      type,
      amount: result.amount,
      category,
      remark: remark.trim(),
      ...(workDate ? { workDate } : {}),
    })
    onSaved?.()
    haptic()
    onClose()
  }

  const closeManager = () => {
    setCategory((current) => {
      const options = getAvailableLedgerCategories(
        type,
        customCategories,
        entry?.category,
      )
      return options.includes(current) ? current : options[0]
    })
    setManagerOpen(false)
  }

  const handleDelete = () => {
    if (!entry) return
    setConfirmDelete(true)
  }

  return (
    <>
      <div className="sheet-backdrop" onClick={onClose}>
        <section
          className="day-sheet"
          role="dialog"
          aria-modal="true"
          aria-label={entry ? '编辑账目' : '记一笔'}
          onClick={(event) => event.stopPropagation()}
        >
          <div className="sheet-header">
            <h2>{entry ? '编辑账目' : '记一笔'}</h2>
            <button type="button" className="icon-button" onClick={onClose} aria-label="关闭">
              <X size={20} />
            </button>
          </div>

          <div className="segmented" aria-label="收支类型">
            <button
              type="button"
              className={type === 'expense' ? 'segment active expense' : 'segment'}
              aria-pressed={type === 'expense'}
              onClick={() => handleTypeChange('expense')}
            >
              支出
            </button>
            <button
              type="button"
              className={type === 'income' ? 'segment active income' : 'segment'}
              aria-pressed={type === 'income'}
              onClick={() => handleTypeChange('income')}
            >
              收入
            </button>
          </div>

          <label className="field">
            <span className="field-label">金额</span>
            <span className="input-with-prefix">
              <span className="field-prefix">¥</span>
              <input
                type="number"
                inputMode="decimal"
                min="0.01"
                step="0.01"
                value={amount}
                autoFocus
                onChange={(event) => {
                  setAmount(event.target.value)
                  setError('')
                }}
                placeholder="0.00"
              />
            </span>
          </label>
          {error ? <p className="error-text">{error}</p> : null}

          <label className="field">
            <span className="field-label">日期</span>
            <input
              type="date"
              value={date}
              onChange={(event) => setDate(event.target.value)}
            />
          </label>

          <div className="field">
            <span className="field-label">分类</span>
            <div className="category-select-row">
              <select
                value={category}
                onChange={(event) => setCategory(event.target.value)}
                aria-label="分类"
              >
                {categoryOptions.map((item) => (
                  <option key={item} value={item}>
                    {item}
                  </option>
                ))}
              </select>
              <button
                type="button"
                className="icon-button"
                onClick={() => setManagerOpen(true)}
                aria-label="管理分类"
                title="管理分类"
              >
                <Tags size={18} />
              </button>
            </div>
          </div>

          <label className="field">
            <span className="field-label">关联工时</span>
            <select
              value={workDate}
              onChange={(event) => setWorkDate(event.target.value)}
              aria-label="关联工时"
            >
              <option value="">不关联</option>
              {sortedRecords.map((record) => (
                <option key={record.date} value={record.date}>
                  {record.date} · {formatHours(record.hours)}小时
                  {record.remark ? ` · ${record.remark}` : ''}
                </option>
              ))}
            </select>
          </label>

          <label className="field">
            <span className="field-label">
              备注
              <span className="field-count">{remark.length}/{MAX_LEDGER_REMARK_LENGTH}</span>
            </span>
            <textarea
              value={remark}
              maxLength={MAX_LEDGER_REMARK_LENGTH}
              onChange={(event) => setRemark(event.target.value)}
              rows={3}
            />
          </label>

          <div className="sheet-actions">
            {entry ? (
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
      </div>

      {managerOpen ? (
        <CategoryManager initialType={type} onClose={closeManager} />
      ) : null}

      {confirmDelete ? (
        <ConfirmDialog
          title="删除这笔记录？"
          message="删除后无法恢复。"
          confirmLabel="删除"
          danger
          onConfirm={() => {
            if (!entry) return
            deleteLedgerEntry(entry.id)
            onDeleted?.(entry)
            haptic([20, 40, 20])
            onClose()
          }}
          onCancel={() => setConfirmDelete(false)}
        />
      ) : null}
    </>
  )
}
