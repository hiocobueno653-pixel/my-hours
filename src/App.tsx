import { CalendarDays, User, WalletCards } from 'lucide-react'
import { App as CapacitorApp } from '@capacitor/app'
import { Capacitor } from '@capacitor/core'
import { useCallback, useEffect, useRef, useState } from 'react'
import type { ThemeMode } from './components/MyView'
import { LedgerView } from './components/LedgerView'
import { MonthView } from './components/MonthView'
import { MyView } from './components/MyView'
import {
  hasModalBackAction,
  requestBackNavigation,
  setRootBackAction,
} from './navigation/backNavigation'

type Tab = 'work' | 'ledger' | 'mine'

function applyThemeMode(mode: ThemeMode) {
  const dark =
    mode === 'dark' ||
    (mode === 'auto' &&
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-color-scheme: dark)').matches)
  document.documentElement.dataset.theme = dark ? 'dark' : 'light'
}

function App() {
  const [tab, setTab] = useState<Tab>('work')
  const [pendingWorkDate, setPendingWorkDate] = useState<string | null>(null)
  const [workEditorOrigin, setWorkEditorOrigin] = useState<Tab | null>(null)
  const [exitHint, setExitHint] = useState('')
  const tabRef = useRef(tab)
  const lastBackAtRef = useRef(0)
  const exitHintTimerRef = useRef<number | null>(null)
  tabRef.current = tab
  const [largeText, setLargeText] = useState(() => {
    try {
      return window.localStorage.getItem('my-hours.largeText') === '1'
    } catch {
      return false
    }
  })

  const toggleLargeText = () => {
    const next = !largeText
    setLargeText(next)
    try {
      window.localStorage.setItem('my-hours.largeText', next ? '1' : '0')
    } catch {
      // 浏览器隐私模式或存储不可用时仍保留当前会话选择
    }
  }

  const handleRootBack = useCallback(() => {
    if (pendingWorkDate) {
      setPendingWorkDate(null)
      if (workEditorOrigin) {
        setTab(workEditorOrigin)
        setWorkEditorOrigin(null)
      }
      return
    }

    if (tabRef.current !== 'work') {
      setTab('work')
      return
    }

    const now = Date.now()
    if (now - lastBackAtRef.current < 2000) {
      if (Capacitor.isNativePlatform()) void CapacitorApp.exitApp()
      return
    }
    lastBackAtRef.current = now
    setExitHint('再按一次返回键退出应用')
    if (exitHintTimerRef.current !== null) {
      window.clearTimeout(exitHintTimerRef.current)
    }
    exitHintTimerRef.current = window.setTimeout(() => setExitHint(''), 2000)
  }, [pendingWorkDate, workEditorOrigin])

  useEffect(() => setRootBackAction(handleRootBack), [handleRootBack])

  // 应用深色模式：初载 + 跟随系统变化
  useEffect(() => {
    let mode: ThemeMode = 'auto'
    try {
      const stored = window.localStorage.getItem('my-hours.theme')
      if (stored === 'light' || stored === 'dark') mode = stored
    } catch {
      // 存储不可用时跟随系统
    }
    applyThemeMode(mode)
    const media = window.matchMedia('(prefers-color-scheme: dark)')
    const onChange = () => {
      let current: ThemeMode = 'auto'
      try {
        const stored = window.localStorage.getItem('my-hours.theme')
        if (stored === 'light' || stored === 'dark') current = stored
      } catch {
        // ignore
      }
      applyThemeMode(current)
    }
    media.addEventListener('change', onChange)
    return () => media.removeEventListener('change', onChange)
  }, [])

  useEffect(() => {
    if (!Capacitor.isNativePlatform()) return undefined
    let disposed = false
    let listener: Awaited<ReturnType<typeof CapacitorApp.addListener>> | null = null
    void CapacitorApp.addListener('backButton', () => {
      // A root-level double-back attempt must not carry across a modal. If a
      // sheet/dialog consumes this press, the next press should start a fresh
      // exit sequence instead of exiting immediately.
      if (hasModalBackAction()) {
        lastBackAtRef.current = 0
      }
      requestBackNavigation()
    }).then((nextListener) => {
      if (disposed) {
        void nextListener.remove()
      } else {
        listener = nextListener
      }
    })
    return () => {
      disposed = true
      if (listener) void listener.remove()
    }
  }, [])

  return (
    <div className={`app-shell${largeText ? ' large-text' : ''}`}>
      <main className="main-content">
        {tab === 'work' ? (
          <MonthView
            initialEditingDate={pendingWorkDate}
            onEditorClosed={() => {
              setPendingWorkDate(null)
              if (workEditorOrigin) {
                setTab(workEditorOrigin)
                setWorkEditorOrigin(null)
              }
            }}
          />
        ) : null}
        {tab === 'ledger' ? <LedgerView /> : null}
        {tab === 'mine' ? (
          <MyView
            largeText={largeText}
            onLargeTextChange={toggleLargeText}
            onOpenDay={(date) => {
              setPendingWorkDate(date)
              setWorkEditorOrigin('mine')
              setTab('work')
            }}
          />
        ) : null}
      </main>
      <nav className="bottom-nav" aria-label="主导航">
        <button
          type="button"
          className={tab === 'work' ? 'nav-button active' : 'nav-button'}
          onClick={() => setTab('work')}
        >
          <span className="nav-icon"><CalendarDays size={21} /></span>
          记工
        </button>
        <button
          type="button"
          className={tab === 'ledger' ? 'nav-button active' : 'nav-button'}
          onClick={() => setTab('ledger')}
        >
          <span className="nav-icon"><WalletCards size={21} /></span>
          记账
        </button>
        <button
          type="button"
          className={tab === 'mine' ? 'nav-button active' : 'nav-button'}
          onClick={() => setTab('mine')}
        >
          <span className="nav-icon"><User size={21} /></span>
          我的
        </button>
      </nav>
      {exitHint ? (
        <p className="exit-hint" role="status">
          {exitHint}
        </p>
      ) : null}
    </div>
  )
}

export default App
