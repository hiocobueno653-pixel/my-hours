import type { CSSProperties } from 'react'

export interface BarGroup {
  label: string
  values: { value: number; color: string }[]
}

interface BarChartProps {
  data: BarGroup[]
  height?: number
  valueFormatter?: (value: number) => string
  ariaLabel: string
  /** 点击某一组（月份）时的回调，index 对应 data 下标 */
  onGroupClick?: (groupIndex: number) => void
}

/**
 * 轻量纯 SVG 柱状图（无依赖，支持多系列）。
 * 颜色接受 CSS 变量（如 var(--accent)），随主题自动切换。
 */
export function BarChart({
  data,
  height = 150,
  valueFormatter = (value) => String(value),
  ariaLabel,
  onGroupClick,
}: BarChartProps) {
  const width = 340
  const padTop = 14
  const padBottom = 24
  const plotH = height - padTop - padBottom
  const plotW = width - 4
  const maxValue = Math.max(
    1,
    ...data.flatMap((group) => group.values.map((item) => item.value)),
  )
  const groupWidth = plotW / Math.max(1, data.length)
  const seriesCount = Math.max(1, ...data.map((group) => group.values.length))
  const barGroupWidth = groupWidth * 0.58
  const barWidth = barGroupWidth / seriesCount
  const gap = barWidth * 0.2
  const gridLines = [0.25, 0.5, 0.75, 1]

  return (
    <svg
      className="bar-chart"
      viewBox={`0 0 ${width} ${height}`}
      role="img"
      aria-label={ariaLabel}
      preserveAspectRatio="none"
    >
      {gridLines.map((ratio) => {
        const y = padTop + plotH - plotH * ratio
        return (
          <line
            key={ratio}
            x1={0}
            x2={width}
            y1={y}
            y2={y}
            className="bar-chart-grid"
          />
        )
      })}
      {data.map((group, groupIndex) => {
        const groupX = groupIndex * groupWidth
        const groupCenter = groupX + groupWidth / 2
        return (
          <g key={groupIndex} className={onGroupClick ? 'bar-group clickable' : 'bar-group'}>
            {group.values.map((item, seriesIndex) => {
              const barH = item.value > 0 ? Math.max(2, (item.value / maxValue) * plotH) : 0
              const x =
                groupCenter -
                barGroupWidth / 2 +
                seriesIndex * barWidth +
                (seriesCount === 1 ? 0 : gap / 2)
              const y = padTop + plotH - barH
              return (
                <rect
                  key={seriesIndex}
                  x={x}
                  y={y}
                  width={Math.max(2, barWidth - gap)}
                  height={barH}
                  rx={Math.min(4, barWidth / 2.5)}
                  fill={item.color}
                  className={`bar-chart-bar series-${seriesIndex}${item.value > 0 ? '' : ' is-empty'}`}
                  style={{ '--bar-index': groupIndex * seriesCount + seriesIndex } as CSSProperties}
                  role={onGroupClick ? 'button' : undefined}
                  tabIndex={onGroupClick ? 0 : undefined}
                  onClick={onGroupClick ? () => onGroupClick(groupIndex) : undefined}
                  onKeyDown={onGroupClick ? (event) => {
                    if (event.key === 'Enter' || event.key === ' ') {
                      event.preventDefault()
                      onGroupClick(groupIndex)
                    }
                  } : undefined}
                  aria-label={`${group.label}：${valueFormatter(item.value)}`}
                >
                  <title>{`${group.label}：${valueFormatter(item.value)}`}</title>
                </rect>
              )
            })}
            <text
              className="bar-chart-label"
              x={groupCenter}
              y={height - 6}
              textAnchor="middle"
            >
              {group.label}
            </text>
          </g>
        )
      })}
    </svg>
  )
}
