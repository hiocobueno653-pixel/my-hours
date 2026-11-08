import { BadgeCheck, CheckCircle2, Pencil, X } from 'lucide-react'
import { useMemo, useState } from 'react'
import { formatMoney } from '../data/ledger'
import { formatDateLabel, todayISO, weekdayName } from '../data/dates'
import { formatHours, getEffectiveRate } from '../data/records'
import { DEFAULT_WORK_ID, getWorkById } from '../data/profiles'
import type { LedgerEntry, WorkDayRecord } from '../data/types'
import { useAppStore } from '../store/useAppStore'
import { haptic } from '../utils/haptics'
import { useModalLayer } from '../navigation/backNavigation'
import { ConfirmDialog } from './ConfirmDialog'

// 「只记工时」变体（VITE_HOURS_ONLY=1 构建）：隐藏工作/工资/结算相关内容
const HOURS_ONLY = import.meta.env.VITE_HOURS_ONLY === '1'

interface DayDetailProps {
  date: string
  record?: WorkDayRecord
  onEdit: () => void
  onClose: () => void
}

/** 某天记录的只读详情弹层：查看信息，想修改时点「修改」进入编辑器；
    有工资时底部「关闭」变为「结算/取消结算」，一笔一笔标记到账 */
export function DayDetail({ date, record, onEdit, onClose }: DayDetailProps) {
  const { containerRef, onKeyDown } = useModalLayer(onClose)
  const workProfiles = useAppStore((state) => state.workProfiles)
  const entries = useAppStore((state) => state.entries)
  const setRecordSettled = useAppStore((state) => state.setRecordSettled)
  const [confirmUnsettle, setConfirmUnsettle] = useState(false)

  const { linkedIncome, dayEntries } = useMemo(() => {
    let linkedIncome: LedgerEntry | undefined
    const dayEntries: LedgerEntry[] = []
    for (const entry of entries) {
      if (entry.date === date) dayEntries.push(entry)
      if (
        entry.type === 'income' &&
        entry.workDate === date &&
        linkedIncome === undefined
      ) {
        linkedIncome = entry
      }
    }
    return { linkedIncome, dayEntries }
  }, [date, entries])
  const workId = record?.workId ?? DEFAULT_WORK_ID
  // getWorkById 含默认工作：它的时薪同样用于回退与展示（改名后也显示正确名称）
  const selectedWork = getWorkById(workProfiles, workId)
  const workName = selectedWork?.name ?? '默认工作'
  // 显示单价：与统计同一公开口径（快照 >0 优先，否则当前工作时薪）
  const effectiveRate = getEffectiveRate({ rate: record?.rate, workId }, workProfiles)
  const hasFixedPay =
    record?.fixedPay !== undefined && Number.isFinite(record.fixedPay) && record.fixedPay > 0
  const dayPay = hasFixedPay
    ? Math.round((record?.fixedPay ?? 0) * 100) / 100
    : Math.round((record?.hours ?? 0) * effectiveRate * 100) / 100

  // 有工资才能结算（dayPay>0），否则显示"关闭"；可在编辑器自定义填工资
  const canSettle = record !== undefined && dayPay > 0
  const isSettled = Boolean(record?.settled)

  // 结算直接执行；取消结算是"改状态"操作，先弹确认避免误触
  const handleSettle = () => {
    if (!canSettle) return
    setRecordSettled(date, true)
    haptic(30)
  }

  const handleUnsettle = () => {
    if (!canSettle) return
    setConfirmUnsettle(true)
  }

  const confirmUnsettleNow = () => {
    setRecordSettled(date, false)
    setConfirmUnsettle(false)
    haptic(30)
  }
  const weekday = weekdayName(new Date(`${date}T00:00:00`).getDay())
  const title =
    date === todayISO() ? `今天 · 周${weekday}` : `${formatDateLabel(date)} · 周${weekday}`
  const hasRecord = record && record.hours > 0

  return (
    <div className="sheet-backdrop" ref={containerRef} onClick={onClose} onKeyDown={onKeyDown}>
      <section
        className="day-sheet day-detail-sheet"
        role="dialog"
        aria-modal="true"
        aria-label={`${date} 详情`}
        onClick={(event) => event.stopPropagation()}
      >
        <div className="sheet-header">
          <div className="day-nav">
            <h2>{title}</h2>
          </div>
          <button type="button" className="icon-button" onClick={onClose} aria-label="关闭">
            <X size={20} />
          </button>
        </div>

        <div className="day-detail-hero">
          <span>工时</span>
          <strong>{hasRecord ? formatHours(record!.hours) : '--'}<small> 小时</small></strong>
          {record?.settled ? (
            <span className="day-detail-settled"><BadgeCheck size={13} /> 已结算</span>
          ) : null}
        </div>

        <dl className="day-detail-rows">
          {HOURS_ONLY ? null : (
          <>
          <div>
            <dt>工作</dt>
            <dd>{workName}</dd>
          </div>
          {hasFixedPay || effectiveRate > 0 ? (
            <>
              {effectiveRate > 0 ? (
                <div>
                  <dt>时薪</dt>
                  <dd>¥{formatMoney(effectiveRate)}</dd>
                </div>
              ) : null}
              <div>
                <dt>{hasFixedPay ? '当日工资' : '本日工资'}</dt>
                <dd className="pay">¥{formatMoney(dayPay)}</dd>
              </div>
            </>
          ) : (
            <div>
              <dt>工资</dt>
              <dd className="muted">未设时薪</dd>
            </div>
          )}
          {linkedIncome ? (
            <div>
              <dt>关联收入</dt>
              <dd className="income">+¥{formatMoney(linkedIncome.amount)} · {linkedIncome.category}</dd>
            </div>
          ) : null}
          </>
          )}
        </dl>

        {record?.remark ? (
          <div className="day-detail-remark">
            <span>备注</span>
            <p>{record.remark}</p>
          </div>
        ) : null}

        {!HOURS_ONLY && dayEntries.length > 0 ? (
          <div className="day-detail-entries">
            <span>当天账目</span>
            <div className="day-detail-entry-list">
              {dayEntries.map((entry) => (
                <div className={`day-detail-entry-row ${entry.type}`} key={entry.id}>
                  <span>{entry.category}</span>
                  <strong className={entry.type}>
                    {entry.type === 'income' ? '+' : '-'}¥{formatMoney(entry.amount)}
                  </strong>
                </div>
              ))}
            </div>
          </div>
        ) : null}

        <div className="sheet-actions">
          {HOURS_ONLY ? null : canSettle ? (
            <button
              type="button"
              className={`button${isSettled ? '' : ' primary'}`}
              onClick={isSettled ? handleUnsettle : handleSettle}
              aria-pressed={isSettled}
            >
              {isSettled ? (
                <>
                  <CheckCircle2 size={16} />
                  取消结算
                </>
              ) : (
                <>
                  <BadgeCheck size={16} />
                  结算
                </>
              )}
            </button>
          ) : (
            <button type="button" className="button" onClick={onClose}>
              关闭
            </button>
          )}
          <button type="button" className={`button${canSettle ? ' ghost' : ' primary'}`} onClick={onEdit}>
            <Pencil size={16} />
            修改
          </button>
        </div>
      </section>

      {confirmUnsettle ? (
        <ConfirmDialog
          title="取消这笔结算？"
          message={`${formatDateLabel(date)} 的工资将标记为未到账，可在详情页重新结算。`}
          danger
          onConfirm={confirmUnsettleNow}
          onCancel={() => setConfirmUnsettle(false)}
        />
      ) : null}
    </div>
  )
}
