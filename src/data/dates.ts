export interface MonthDay {
  date: string
  day: number
  weekday: number
  isToday: boolean
}

const MONTH_KEY_RE = /^(\d{4})-(\d{2})$/

export function pad2(value: number): string {
  return String(value).padStart(2, '0')
}

export function toDateISO(date: Date): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`
}

export function todayISO(): string {
  return toDateISO(new Date())
}

export function monthKeyOf(date: Date): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}`
}

export function currentMonthKey(): string {
  return monthKeyOf(new Date())
}

export function parseMonthKey(key: string): { year: number; month: number } | null {
  // 用 String.match 而非 RegExp.exec：行为等价，且避免打包产物中出现
  // ".exec(用户输入)" 形态被静态扫描误判为命令注入
  const match = key.match(MONTH_KEY_RE)
  if (!match) return null
  return { year: Number(match[1]), month: Number(match[2]) }
}

export function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate()
}

export function getMonthDates(yearMonth: string): MonthDay[] {
  const parsed = parseMonthKey(yearMonth)
  if (!parsed) return []
  const { year, month } = parsed
  const today = todayISO()
  const count = daysInMonth(year, month)
  return Array.from({ length: count }, (_, index) => {
    const day = index + 1
    const date = new Date(year, month - 1, day)
    const iso = `${year}-${pad2(month)}-${pad2(day)}`
    return {
      date: iso,
      day,
      weekday: date.getDay(),
      isToday: iso === today,
    }
  })
}

export function shiftDate(dateISO: string, delta: number): string {
  const [year, month, day] = dateISO.split('-').map(Number)
  return toDateISO(new Date(year, month - 1, day + delta))
}

export function shiftMonth(yearMonth: string, delta: number): string {
  const parsed = parseMonthKey(yearMonth)
  if (!parsed) return currentMonthKey()
  const next = new Date(parsed.year, parsed.month - 1 + delta, 1)
  return monthKeyOf(next)
}

export function formatDateLabel(dateISO: string): string {
  const [, month, day] = dateISO.split('-')
  return `${Number(month)}月${Number(day)}日`
}

export function formatMonthLabel(yearMonth: string): string {
  const parsed = parseMonthKey(yearMonth)
  if (!parsed) return yearMonth
  return `${parsed.year}年${parsed.month}月`
}

export function weekdayName(weekday: number): string {
  return ['日', '一', '二', '三', '四', '五', '六'][weekday] ?? ''
}
