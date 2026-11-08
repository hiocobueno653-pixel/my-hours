import { ChevronLeft, ChevronRight } from 'lucide-react'
import { useMemo, useState } from 'react'
import { parseMonthKey } from '../data/dates'
import { useModalLayer } from '../navigation/backNavigation'

interface MonthPickerProps {
  value: string
  onSelect: (yearMonth: string) => void
  onClose: () => void
}

const MONTHS = Array.from({ length: 12 }, (_, index) => index + 1)

/** 月份选择弹层：年份切换 + 12 个月网格，点击月份即选 */
export function MonthPicker({ value, onSelect, onClose }: MonthPickerProps) {
  const { containerRef, onKeyDown } = useModalLayer(onClose)
  const parsed = parseMonthKey(value)
  const [year, setYear] = useState(parsed?.year ?? new Date().getFullYear())
  const selectedMonth = parsed?.month ?? new Date().getMonth() + 1
  const pad = (n: number) => String(n).padStart(2, '0')

  const years = useMemo(() => {
    const current = new Date().getFullYear()
    const list: number[] = []
    for (let y = current - 5; y <= current + 1; y += 1) list.push(y)
    return list
  }, [])

  return (
    <div className="sheet-backdrop" ref={containerRef} onClick={onClose} onKeyDown={onKeyDown}>
      <section
        className="action-sheet month-picker-sheet"
        role="dialog"
        aria-modal="true"
        aria-label="选择月份"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="month-picker-header">
          <button
            type="button"
            className="icon-button small"
            onClick={() => setYear((current) => current - 1)}
            aria-label="上一年"
          >
            <ChevronLeft size={20} />
          </button>
          <h2>{year} 年</h2>
          <button
            type="button"
            className="icon-button small"
            onClick={() => setYear((current) => current + 1)}
            aria-label="下一年"
          >
            <ChevronRight size={20} />
          </button>
        </div>
        <div className="month-picker-grid" role="grid" aria-label={`${year} 年月份`}>
          {MONTHS.map((month) => {
            const key = `${year}-${pad(month)}`
            const isSelected = key === value
            return (
              <button
                type="button"
                key={month}
                className={`month-picker-cell${isSelected ? ' active' : ''}`}
                aria-pressed={isSelected}
                onClick={() => onSelect(key)}
              >
                {month} 月
                {month === selectedMonth && year === parsed?.year ? <small>本月</small> : null}
              </button>
            )
          })}
        </div>
        {years.length > 0 ? (
          <div className="month-picker-years" aria-label="年份快捷切换">
            {years.map((y) => (
              <button
                type="button"
                key={y}
                className={`month-picker-year${y === year ? ' active' : ''}`}
                aria-pressed={y === year}
                onClick={() => setYear(y)}
              >
                {y}
              </button>
            ))}
          </div>
        ) : null}
      </section>
    </div>
  )
}
