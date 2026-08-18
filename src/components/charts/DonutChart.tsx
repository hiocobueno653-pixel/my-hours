export interface DonutSegment {
  label: string
  value: number
  color: string
}

interface DonutChartProps {
  segments: DonutSegment[]
  size?: number
  thickness?: number
  centerLabel?: string
  centerValue?: string
}

/** 轻量纯 SVG 环形占比图（无依赖） */
export function DonutChart({
  segments,
  size = 132,
  thickness = 20,
  centerLabel,
  centerValue,
}: DonutChartProps) {
  const total = segments.reduce((sum, segment) => sum + segment.value, 0)
  const radius = (size - thickness) / 2
  const circumference = 2 * Math.PI * radius
  const center = size / 2
  let offset = 0

  return (
    <div className="donut-wrap" style={{ width: size, height: size }}>
      <svg
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
        role="img"
        aria-label={segments.map((segment) => `${segment.label} ${segment.value}`).join('，')}
      >
        <circle
          className="donut-track"
          cx={center}
          cy={center}
          r={radius}
          fill="none"
          strokeWidth={thickness}
        />
        {total > 0 ?
          segments.map((segment) => {
            const fraction = segment.value / total
            const length = Math.max(0.5, fraction * circumference)
            const dash = `${length} ${circumference - length}`
            const rotation = -90 + (offset / circumference) * 360
            offset += length
            return (
              <circle
                key={segment.label + segment.color}
                className="donut-segment"
                cx={center}
                cy={center}
                r={radius}
                fill="none"
                stroke={segment.color}
                strokeWidth={thickness}
                strokeDasharray={dash}
                transform={`rotate(${rotation} ${center} ${center})`}
              >
                <title>{`${segment.label}：${segment.value}`}</title>
              </circle>
            )
          })
        : null}
      </svg>
      {centerLabel || centerValue ? (
        <div className="donut-center">
          {centerLabel ? <span>{centerLabel}</span> : null}
          {centerValue ? <strong>{centerValue}</strong> : null}
        </div>
      ) : null}
    </div>
  )
}
