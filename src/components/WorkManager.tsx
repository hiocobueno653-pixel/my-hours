import { Check, Pencil, Plus, Trash2, X } from 'lucide-react'
import { useState } from 'react'
import { formatMoney } from '../data/ledger'
import {
  createWorkProfileId,
  DEFAULT_WORK_ID,
  formatRate,
  MAX_WORK_NAME_LENGTH,
  parseRateInput,
} from '../data/profiles'
import { useAppStore } from '../store/useAppStore'
import { useModalLayer } from '../navigation/backNavigation'
import { ConfirmDialog } from './ConfirmDialog'
import type { WorkProfile } from '../data/types'

interface WorkManagerProps {
  onClose: () => void
}

interface EditingRow {
  id: string
  name: string
  rate: string
}

export function WorkManager({ onClose }: WorkManagerProps) {
  useModalLayer(onClose)
  const workProfiles = useAppStore((state) => state.workProfiles)
  const records = useAppStore((state) => state.records)
  const saveWorkProfile = useAppStore((state) => state.saveWorkProfile)
  const deleteWorkProfile = useAppStore((state) => state.deleteWorkProfile)
  const [name, setName] = useState('')
  const [rate, setRate] = useState('')
  const [editing, setEditing] = useState<EditingRow | null>(null)
  const [message, setMessage] = useState('')
  const [pendingDelete, setPendingDelete] = useState<WorkProfile | null>(null)

  const recordCount = (workId: string) =>
    workId === DEFAULT_WORK_ID
      ? records.filter((record) => !record.workId || record.workId === DEFAULT_WORK_ID).length
      : records.filter((record) => record.workId === workId).length

  const handleAdd = () => {
    const normalized = name.trim().slice(0, MAX_WORK_NAME_LENGTH)
    if (!normalized) {
      setMessage('请输入工作名称')
      return
    }
    const rateResult = parseRateInput(rate)
    if (!rateResult.ok) {
      setMessage(rateResult.error)
      return
    }
    const duplicate = workProfiles.some(
      (profile) => profile.id !== DEFAULT_WORK_ID && profile.name === normalized,
    )
    if (duplicate) {
      setMessage('已存在同名工作')
      return
    }
    saveWorkProfile({
      id: createWorkProfileId(),
      name: normalized,
      hourlyRate: rateResult.rate,
    })
    setName('')
    setRate('')
    setMessage('工作已添加')
  }

  const startEdit = (profile: WorkProfile) => {
    setEditing({
      id: profile.id,
      name: profile.name,
      rate: profile.hourlyRate > 0 ? formatRate(profile.hourlyRate) : '',
    })
    setMessage('')
  }

  const saveEdit = () => {
    if (!editing) return
    const target = workProfiles.find((profile) => profile.id === editing.id)
    if (!target) return
    const normalized = editing.name.trim().slice(0, MAX_WORK_NAME_LENGTH)
    if (!normalized) {
      setMessage('名称不能为空')
      return
    }
    const rateResult = parseRateInput(editing.rate)
    if (!rateResult.ok) {
      setMessage(rateResult.error)
      return
    }
    saveWorkProfile({
      id: target.id,
      name: normalized,
      hourlyRate: rateResult.rate,
    })
    setEditing(null)
    setMessage('已保存')
  }

  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <section
        className="day-sheet work-sheet"
        role="dialog"
        aria-modal="true"
        aria-label="管理工作"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="sheet-header">
          <h2>管理工作</h2>
          <button type="button" className="icon-button" onClick={onClose} aria-label="关闭">
            <X size={20} />
          </button>
        </div>
        <p className="field-note">
          为每份工作设置时薪，记工时后按「工时 × 时薪」自动算工资；已有记录沿用记录时的时薪。
        </p>

        <div className="work-list">
          {workProfiles.map((profile) => {
            const isDefault = profile.id === DEFAULT_WORK_ID
            const count = recordCount(profile.id)
            if (editing?.id === profile.id) {
              return (
                <div className="work-row editing" key={profile.id}>
                  <div className="work-edit-fields">
                    <input
                      value={editing.name}
                      maxLength={MAX_WORK_NAME_LENGTH}
                      onChange={(event) =>
                        setEditing({ ...editing, name: event.target.value })
                      }
                      aria-label="工作名称"
                    />
                    <span className="input-with-suffix work-rate-input">
                      <input
                        type="number"
                        inputMode="decimal"
                        min="0"
                        step="0.01"
                        value={editing.rate}
                        onChange={(event) =>
                          setEditing({ ...editing, rate: event.target.value })
                        }
                        placeholder="时薪"
                        aria-label="时薪"
                      />
                      <span className="field-suffix">元/时</span>
                    </span>
                  </div>
                  <div className="work-row-actions">
                    <button type="button" className="icon-button" onClick={saveEdit} aria-label="保存">
                      <Check size={18} />
                    </button>
                    <button
                      type="button"
                      className="icon-button"
                      onClick={() => setEditing(null)}
                      aria-label="取消"
                    >
                      <X size={18} />
                    </button>
                  </div>
                </div>
              )
            }
            return (
              <div className="work-row" key={profile.id}>
                <div className="work-row-main">
                  <strong>{profile.name}</strong>
                  {isDefault ? <span className="category-kind">默认</span> : null}
                  <span className="work-rate">
                    {profile.hourlyRate > 0
                      ? `¥${formatMoney(profile.hourlyRate)}/时`
                      : '未设时薪'
                    }
                  </span>
                  <span className="work-count">{count} 天记录</span>
                </div>
                <div className="work-row-actions">
                  <button
                    type="button"
                    className="icon-button small"
                    onClick={() => startEdit(profile)}
                    aria-label={`编辑${profile.name}`}
                  >
                    <Pencil size={16} />
                  </button>
                  {!isDefault ? (
                    <button
                      type="button"
                      className="icon-button small"
                      onClick={() => setPendingDelete(profile)}
                      aria-label={`删除${profile.name}`}
                    >
                      <Trash2 size={16} />
                    </button>
                  ) : null}
                </div>
              </div>
            )
          })}
        </div>

        <div className="work-add-row">
          <input
            value={name}
            maxLength={MAX_WORK_NAME_LENGTH}
            onChange={(event) => {
              setName(event.target.value)
              setMessage('')
            }}
            aria-label="新工作名称"
            placeholder="工作名称（如：工地A、家教）"
          />
          <span className="input-with-suffix work-rate-input">
            <input
              type="number"
              inputMode="decimal"
              min="0"
              step="0.01"
              value={rate}
              onChange={(event) => {
                setRate(event.target.value)
                setMessage('')
              }}
              placeholder="时薪"
              aria-label="时薪"
            />
            <span className="field-suffix">元/时</span>
          </span>
          <button type="button" className="button primary" onClick={handleAdd}>
            <Plus size={18} />
            添加
          </button>
        </div>
        {message ? <p className="status-line">{message}</p> : null}
      </section>

      {pendingDelete ? (
        <ConfirmDialog
          title={`删除「${pendingDelete.name}」？`}
          message={recordCount(pendingDelete.id) > 0
            ? `该工作有 ${recordCount(pendingDelete.id)} 天记录，删除后记录归入默认工作，历史工资不受影响。`
            : '删除后无法恢复。'
          }
          confirmLabel="删除"
          danger
          onConfirm={() => {
            deleteWorkProfile(pendingDelete.id)
            setPendingDelete(null)
            setMessage('已删除')
          }}
          onCancel={() => setPendingDelete(null)}
        />
      ) : null}
    </div>
  )
}
