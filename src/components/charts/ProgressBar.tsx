interface ProgressBarProps {
  value: number
  max: number
  tone?: 'accent' | 'income' | 'expense' | 'gold'
  height?: number
}

export function ProgressBar({
  value,
  max,
  tone = 'accent',
  height = 8,
}: ProgressBarProps) {
  const ratio = max > 0 ? Math.min(value / max, 1) : 0
  const percent = Math.round(ratio * 100)
  const label = max > 0 ? `${Math.round((value / max) * 100)}%` : '未设置'

  return (
    <div
      className="progress-bar"
      style={{ height }}
      role="progressbar"
      aria-valuenow={Math.round(value * 100) / 100}
      aria-valuemin={0}
      aria-valuemax={Math.max(1, max)}
      aria-label={label}
    >
      <div
        className={`progress-fill ${tone}`}
        style={{ width: `${percent}%` }}
      />
    </div>
  )
}
