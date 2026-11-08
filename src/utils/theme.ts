import { Capacitor, SystemBars, SystemBarsStyle } from '@capacitor/core'

export type ThemeMode = 'auto' | 'light' | 'dark'

function resolveDark(mode: ThemeMode): boolean {
  return (
    mode === 'dark' ||
    (mode === 'auto' &&
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-color-scheme: dark)').matches)
  )
}

// Theme + Capacitor system bar icon color. 
export function applyThemeMode(mode: ThemeMode): void {
  const dark = resolveDark(mode)
  document.documentElement.dataset.theme = dark ? 'dark' : 'light'
  const themeColor = dark ? '#141414' : '#f4f5f7'
  let meta = document.querySelector('meta[name="theme-color"]')
  if (!meta) {
    meta = document.createElement('meta')
    meta.setAttribute('name', 'theme-color')
    document.head.appendChild(meta)
  }
  meta.setAttribute('content', themeColor)
  if (Capacitor.isNativePlatform()) {
    void SystemBars.setStyle({
      style: dark ? SystemBarsStyle.Dark : SystemBarsStyle.Light,
    })
  }
}
