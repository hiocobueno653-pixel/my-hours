import { CalendarOff, ChevronDown, ChevronLeft, ChevronRight } from 'lucide-react'
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from 'react'
import {
  formatDateLabel,
  formatMonthLabel,
  shiftMonth,
  weekdayName,
} from '../data/dates'
import {
  getMonthActivities,
  getRecordedActivities,
  type DayActivity,
} from '../data/activity'
import { formatMoney } from '../data/ledger'
import { formatHours, getMonthDelta, getMonthPay, getMonthSummary, getRecordPay, getSettlementSummary } from '../data/records'
import type { WorkDayRecord, WorkProfile } from '../data/types'
import { useAppStore } from '../store/useAppStore'
import { haptic } from '../utils/haptics'
import { useModalLayer } from '../navigation/backNavigation'
import { MonthPicker } from './MonthPicker'

// 「只记工时」变体（VITE_HOURS_ONLY=1 构建）：概要与行内不显示工资/结算
const HOURS_ONLY = import.meta.env.VITE_HOURS_ONLY === '1'

interface MonthDetailProps {
  initialMonth: string
  onClose: () => void
  /** 最近被删除的日期（含动画），用于本页内行删除动效 */
  exitingDate?: string | null
  /** 删除发生前的记录快照，离场行按此渲染（删除后 store 中已无此记录） */
  exitingRecord?: WorkDayRecord | null
  /** 离场动画播完时回调（父层据此清除 exitingDate，避免重复播放） */
  onExitComplete?: () => void
  onOpenDay: (date: string) => void
}

const EXIT_MS = 280

/**
 * 二级界面：本月明细。从右侧滑入、返回时滑出；自带月份/年份切换与行入场动画。
 * 最近删除的行会被保留一小段时间以播放删除动画，由父组件在动画结束后清空。
 */
export function MonthDetail({
  initialMonth,
  onClose,
  exitingDate,
  exitingRecord,
  onExitComplete,
  onOpenDay,
}: MonthDetailProps) {
  const records = useAppStore((state) => state.records)
  const entries = useAppStore((state) => state.entries)
  const workProfiles = useAppStore((state) => state.workProfiles)
  const [month, setMonth] = useState(initialMonth)
  const [pickerOpen, setPickerOpen] = useState(false)
  const [slideDir, setSlideDir] = useState<'left' | 'right' | null>(null)
  const slideTimerRef = useRef<number | null>(null)

  const [leaving, setLeaving] = useState(false)
  const [showAll, setShowAll] = useState(false)
  const [exiting, setExiting] = useState<DayActivity | null>(null)
  const exitingTimerRef = useRef<number | null>(null)
  const backTimerRef = useRef<number | null>(null)

  useEffect(() => {
    return () => {
      if (slideTimerRef.current !== null) window.clearTimeout(slideTimerRef.current)
      if (exitingTimerRef.current !== null) window.clearTimeout(exitingTimerRef.current)
      if (backTimerRef.current !== null) window.clearTimeout(backTimerRef.current)
    }
  }, [])

  useEffect(() => {
    setShowAll(false)
  }, [month])

  const handleBack = useCallback(() => {
    if (leaving) return
    setLeaving(true)
    if (backTimerRef.current !== null) window.clearTimeout(backTimerRef.current)
    backTimerRef.current = window.setTimeout(onClose, 320)
  }, [leaving, onClose])
  const { containerRef, onKeyDown } = useModalLayer(handleBack)

  const activities = useMemo(
    () => getMonthActivities(month, records, entries),
    [month, records, entries],
  )
  const recorded = useMemo(
    () => getRecordedActivities(activities),
    [activities],
  )
  const visible = showAll ? recorded : recorded.slice(0, 6)
  const summary = useMemo(() => getMonthSummary(records, month), [records, month])
  const monthPay = useMemo(
    () => getMonthPay(records, month, workProfiles),
    [records, month, workProfiles],
  )
  const settlement = useMemo(
    () => getSettlementSummary(records, month, workProfiles),
    [records, month, workProfiles],
  )
  const monthDelta = useMemo(
    () => getMonthDelta(records, month, shiftMonth),
    [records, month],
  )

  // 当父层报告一个被删除的日期，本地保留其行以播放删除动效。
  // 离场行按删除前的记录快照渲染（删除后 store 中该记录已不存在）。
  // 仅当该日期属于当前明细月份时播放；跨月删除不在此页重播。
  // 动画结束后通知父层清空 exitingDate，避免同一次删除被重复播放。
  useEffect(() => {
    if (!exitingDate) {
      setExiting(null)
      return
    }
    const found = activities.find((item) => item.date === exitingDate)
    if (!found) {
      setExiting(null)
      return
    }
    setExiting({ ...found, record: exitingRecord ?? found.record })
    if (exitingTimerRef.current !== null) window.clearTimeout(exitingTimerRef.current)
    exitingTimerRef.current = window.setTimeout(() => {
      setExiting(null)
      onExitComplete?.()
    }, EXIT_MS)
    return () => {
      if (exitingTimerRef.current !== null) {
        window.clearTimeout(exitingTimerRef.current)
        exitingTimerRef.current = null
      }
    }
  }, [exitingDate, exitingRecord, activities, onExitComplete])

  const goPrevMonth = () => {
    setSlideDir('right')
    if (slideTimerRef.current !== null) window.clearTimeout(slideTimerRef.current)
    slideTimerRef.current = window.setTimeout(() => setSlideDir(null), 400)
    setMonth((current) => shiftMonth(current, -1))
  }
  const goNextMonth = () => {
    setSlideDir('left')
    if (slideTimerRef.current !== null) window.clearTimeout(slideTimerRef.current)
    slideTimerRef.current = window.setTimeout(() => setSlideDir(null), 400)
    setMonth((current) => shiftMonth(current, 1))
  }

  return (
    <div
      ref={containerRef}
      onKeyDown={onKeyDown}
      className={`month-detail page-push${leaving ? ' leaving' : ''}`}
      role="dialog"
      aria-modal="true"
      aria-label="本月明细"
    >
      <header className="detail-page-header">
        <button
          type="button"
          className="icon-button"
          onClick={handleBack}
          aria-label="返回"
        >
          <ChevronLeft size={22} />
        </button>
        <div className="inline-month-nav" aria-label="月份切换">
          <button
            type="button"
            className="month-nav-button"
            onClick={goPrevMonth}
            aria-label="上个月"
          >
            <ChevronLeft size={19} />
          </button>
          <h2
            className="month-nav-label"
            tabIndex={0}
            title="选择月份"
            onClick={() => setPickerOpen(true)}
            onKeyDown={(event) => {
              if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault()
                setPickerOpen(true)
              }
            }}
          >
            {formatMonthLabel(month)}
          </h2>
          <button
            type="button"
            className="month-nav-button"
            onClick={goNextMonth}
            aria-label="下个月"
          >
            <ChevronRight size={19} />
          </button>
        </div>
      </header>

      <section className="detail-summary" aria-label="月总计">
        <div className="detail-summary-primary">
          <span>本月工时</span>
          <strong>{formatHours(summary.totalHours)}<small> 小时</small></strong>
        </div>
        <div className="detail-summary-secondary">
          <div>
            <dt>工作日</dt>
            <dd>{summary.workDays}<small> 天</small></dd>
          </div>
          {HOURS_ONLY ? null : (
          <div>
            <dt>待结算</dt>
            <dd className={monthPay > 0 ? 'pay' : ''}>
              {monthPay > 0 ? `¥${formatMoney(settlement.pending)}` : '未设时薪'}
            </dd>
          </div>
          )}
          {!HOURS_ONLY && monthPay > 0 ? (
            <div>
              <dt>已结算</dt>
              <dd className="pay">¥{formatMoney(settlement.settled)}</dd>
            </div>
          ) : null}
        </div>
        {monthDelta ? (
          <span className={`detail-delta${monthDelta.delta >= 0 ? ' up' : ' down'}`}>
            {monthDelta.delta >= 0 ? '↑' : '↓'} 较上月 {monthDelta.delta >= 0 ? '+' : ''}
            {formatHours(monthDelta.delta)} 小时
          </span>
        ) : null}
      </section>

      <section className="detail-activity" aria-label="每日记录">
        <div className="day-list-heading">
          <span>每日记录</span>
          <small>{recorded.length > 0 ? `${recorded.length} 天有记录` : '暂无记录'}</small>
        </div>
        {visible.length > 0 || exiting ? (
          <div
            key={month}
            className={`detail-activity-list${slideDir ? ` slide-${slideDir}` : ''}`}
            onAnimationEnd={() => setSlideDir(null)}
          >
            {exiting ? (
              <DetailRow
                key={`exit-${exiting.date}`}
                activity={exiting}
                workProfiles={workProfiles}
                leaving
                onOpen={() => {}}
              />
            ) : null}
            {visible
              .filter((activity) => activity.date !== exiting?.date)
              .map((activity, index) => (
                <DetailRow
                  key={activity.date}
                  activity={activity}
                  workProfiles={workProfiles}
                  index={index}
                  onOpen={() => {
                    haptic()
                    onOpenDay(activity.date)
                  }}
                />
              ))}
            {recorded.length > 6 ? (
              <button
                type="button"
                className="month-activity-more"
                onClick={() => setShowAll((current) => !current)}
                aria-expanded={showAll}
              >
                {showAll ? '收起记录' : `查看全部 ${recorded.length} 天`}
                <ChevronDown className={showAll ? 'open' : ''} size={17} aria-hidden="true" />
              </button>
            ) : null}
          </div>
        ) : (
          <div className="detail-empty">
            <CalendarOff size={28} aria-hidden="true" />
            <strong>这个月还没有记录</strong>
            <span>点击主页面日历中的日期即可补记工时。</span>
          </div>
        )}
      </section>

      {pickerOpen ? (
        <MonthPicker
          value={month}
          onSelect={(next) => {
            setMonth(next)
            setPickerOpen(false)
          }}
          onClose={() => setPickerOpen(false)}
        />
      ) : null}
    </div>
  )
}

function DetailRow({
  activity,
  workProfiles,
  index,
  leaving = false,
  onOpen,
}: {
  activity: DayActivity
  workProfiles?: WorkProfile[]
  index?: number
  leaving?: boolean
  onOpen: () => void
}) {
  const wage = activity.record
    ? getRecordPay(activity.record, workProfiles)
    : 0
  return (
    <button
      type="button"
      className={`detail-activity-row${leaving ? ' leaving' : ''}`}
      style={index !== undefined ? ({ '--row-index': index } as CSSProperties) : undefined}
      onClick={onOpen}
      disabled={leaving}
      aria-label={`${formatDateLabel(activity.date)} · 周${weekdayName(activity.weekday)}，打开当天记录`}
    >
      <span className="activity-date">
        <strong>{activity.day}</strong>
        <small>周{weekdayName(activity.weekday)}</small>
      </span>
      <span className="activity-content">
        <span className="activity-primary">
          {activity.record ? (
            <strong>{formatHours(activity.record.hours)} 小时</strong>
          ) : (
            <strong>仅账目</strong>
          )}
          {!HOURS_ONLY && wage > 0 ? (
            <span className={activity.record?.settled ? 'activity-wage settled' : 'activity-wage'}>
              {activity.record?.settled ? '已结算' : '工资'} ¥{formatMoney(wage)}
            </span>
          ) : null}
        </span>
        <span className="activity-secondary">
          {activity.record?.remark ? <span>{activity.record.remark}</span> : null}
          {activity.dayIncome > 0 ? (
            <span className="activity-amount income">+¥{formatMoney(activity.dayIncome)}</span>
          ) : null}
          {activity.dayExpense > 0 ? (
            <span className="activity-amount expense">-¥{formatMoney(activity.dayExpense)}</span>
          ) : null}
          {activity.linkedCount > 0 ? <span>{activity.linkedCount} 笔关联</span> : null}
        </span>
      </span>
      <ChevronRight className="activity-chevron" size={18} aria-hidden="true" />
    </button>
  )
}
