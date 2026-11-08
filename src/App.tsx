import { CalendarDays, User, WalletCards } from 'lucide-react'
import { App as CapacitorApp } from '@capacitor/app'
import { Capacitor } from '@capacitor/core'
import { useCallback, useEffect, useRef, useState, type CSSProperties } from 'react'
import { applyThemeMode, type ThemeMode } from './utils/theme'
import { LedgerView } from './components/LedgerView'
import { MonthView } from './components/MonthView'
import { MyView } from './components/MyView'
import {
  hasModalBackAction,
  requestBackNavigation,
  setRootBackAction,
} from './navigation/backNavigation'

// 「只记工时」变体（VITE_HOURS_ONLY=1 构建）：隐藏记账入口
const HOURS_ONLY = import.meta.env.VITE_HOURS_ONLY === '1'

type Tab = 'work' | 'ledger' | 'mine'


function App() {
  const [tab, setTab] = useState<Tab>('work')
  const [lensFrom, setLensFrom] = useState<Tab>('work')
  const lensTimerRef = useRef<number | null>(null)
  const [navHidden, setNavHidden] = useState(false)
  const [pendingWorkDate, setPendingWorkDate] = useState<string | null>(null)
  const [pendingLedgerDate, setPendingLedgerDate] = useState<string | null>(null)
  const [workEditorOrigin, setWorkEditorOrigin] = useState<Tab | null>(null)
  const [exitHint, setExitHint] = useState('')
  const tabRef = useRef(tab)
  const lastBackAtRef = useRef(0)
  const exitHintTimerRef = useRef<number | null>(null)
  tabRef.current = tab
  // lens 位置索引：完整版 3 Tab（0/1/2）；「只记工时」2 Tab（记工 0 / 我的 1），
  // 与 CSS 的 lens 宽度（1/2）和列数保持一致，否则镜头会滑出按钮位置
  const tabIndex: Record<Tab, number> = HOURS_ONLY
    ? { work: 0, ledger: 1, mine: 1 }
    : { work: 0, ledger: 1, mine: 2 }
  const tabOrder: Tab[] = HOURS_ONLY ? ['work', 'mine'] : ['work', 'ledger', 'mine']
  const navCols = tabOrder.length

  // 底部导航液态滑动：切换时主 lens 从旧位置"流动"到新位置（平移+轻微形变），
  // 旧位置同时出现一个收缩淡出的离场 lens，产生"前一个自然流到这边"的 morphing。
  const suppressClickRef = useRef(false)
  const switchTab = (next: Tab) => {
    if (suppressClickRef.current) {
      suppressClickRef.current = false
      return
    }
    if (next === tab) return
    setLensFrom(tab)
    setTab(next)
    if (lensTimerRef.current !== null) window.clearTimeout(lensTimerRef.current)
    lensTimerRef.current = window.setTimeout(() => setLensFrom(next), 480)
  }
  useEffect(() => () => {
    if (lensTimerRef.current !== null) window.clearTimeout(lensTimerRef.current)
    if (exitHintTimerRef.current !== null) window.clearTimeout(exitHintTimerRef.current)
  }, [])

  // ---- 拖拽液态透镜 + 双层 clip-path 局部变色 ----
  const navRef = useRef<HTMLElement | null>(null)
  // 拖拽中：lens 中心相对 nav 的 x（px）；null = 未拖拽
  const [dragX, setDragX] = useState<number | null>(null)
  const dragGeomRef = useRef<{ tintW: number; lensW: number } | null>(null)
  const dragMovedRef = useRef(false)
  // 高亮层裁剪窗口（相对 tint 层，px）：滑块滑过哪里，哪里的图标文字变品牌色
  const [clip, setClip] = useState({ left: 0, right: 0 })
  const clipRafRef = useRef<number | null>(null)

  const syncClipFromLens = useCallback(() => {
    const nav = navRef.current
    const tint = nav?.querySelector<HTMLElement>('.nav-tint')
    const lens = nav?.querySelector<HTMLElement>('.liquid-nav-lens')
    if (!tint || !lens) return
    const tintRect = tint.getBoundingClientRect()
    const lensRect = lens.getBoundingClientRect()
    setClip({
      left: Math.max(0, lensRect.left - tintRect.left),
      right: Math.min(tintRect.width, lensRect.right - tintRect.left),
    })
  }, [])

  // 切换后跟随 lens morph 动画逐帧同步 clip（420ms 动画 + 余量）
  useEffect(() => {
    const start = performance.now()
    const tick = () => {
      syncClipFromLens()
      if (performance.now() - start < 520) {
        clipRafRef.current = requestAnimationFrame(tick)
      }
    }
    clipRafRef.current = requestAnimationFrame(tick)
    return () => {
      if (clipRafRef.current !== null) cancelAnimationFrame(clipRafRef.current)
    }
  }, [tab, syncClipFromLens])

  const onNavPointerDown = (event: React.PointerEvent) => {
    if (event.button !== 0) return
    const nav = navRef.current
    if (!nav) return
    const navRect = nav.getBoundingClientRect()
    const cols = tabOrder.length
    dragGeomRef.current = {
      tintW: navRect.width - 10,
      lensW: (navRect.width - 10) / cols,
    }
    nav.setPointerCapture(event.pointerId)
    dragMovedRef.current = false
    setDragX(event.clientX - navRect.left)
  }
  const onNavPointerMove = (event: React.PointerEvent) => {
    if (dragX === null) return
    const nav = navRef.current
    if (!nav) return
    const x = event.clientX - nav.getBoundingClientRect().left
    if (Math.abs(x - dragX) > 4) dragMovedRef.current = true
    setDragX(x)
  }
  const endNavDrag = (event: React.PointerEvent) => {
    if (dragX === null) return
    setDragX(null)
    dragGeomRef.current = null
    const nav = navRef.current
    if (!nav) return
    if (dragMovedRef.current) suppressClickRef.current = true
    const rect = nav.getBoundingClientRect()
    const slotW = (rect.width - 10) / navCols
    const slot = Math.max(0, Math.min(navCols - 1, Math.floor((event.clientX - rect.left - 5) / slotW)))
    const next = tabOrder[slot]
    if (next !== tabRef.current) switchTab(next)
  }

  // 拖拽中 clip 窗口跟随手指：tint 空间 = nav 空间左移 padding(5px)，透镜直径 = 槽位宽
  const dragClip = (() => {
    const geom = dragGeomRef.current
    if (dragX === null || !geom) return null
    const center = dragX - 5
    return {
      left: Math.max(0, center - geom.lensW / 2),
      right: Math.min(geom.tintW, center + geom.lensW / 2),
    }
  })()
  const activeClip = dragClip ?? clip
  const [largeText, setLargeText] = useState(() => {
    try {
      return window.localStorage.getItem('my-hours.largeText') === '1'
    } catch {
      return false
    }
  })
  const [isScrolled, setIsScrolled] = useState(false)
  // 上滑页面时导航栏整体下沉（浮层移动，玻璃本体零改动，材质不变）
  const [navCompact, setNavCompact] = useState(false)
  const lastScrollYRef = useRef(0)

  // 页面滚动时标记，驱动页头毛玻璃出现分隔线/阴影
  useEffect(() => {
    const onScroll = () => {
      const y = window.scrollY
      const lastY = lastScrollYRef.current
      lastScrollYRef.current = y
      setIsScrolled(y > 8)
      setNavCompact(y > 48 && y >= lastY)
    }
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

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
    <div className={`app-shell${largeText ? ' large-text' : ''}${isScrolled ? ' is-scrolled' : ''}${HOURS_ONLY ? ' hours-only' : ''}`}>
      {/* 渐进式模糊遮罩：顶栏滚过的内容被纵向羽化虚化，无硬边、无分割线 */}
      <div className="progressive-blur" aria-hidden="true" />
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
            onOpenLedger={HOURS_ONLY ? undefined : (date) => {
              setPendingLedgerDate(date)
              setTab('ledger')
            }}
          />
        ) : null}
        {tab === 'ledger' ? (
          <LedgerView
            initialEntryDate={pendingLedgerDate}
            onEntryHandled={() => setPendingLedgerDate(null)}
          />
        ) : null}
        {tab === 'mine' ? (
          <MyView
            largeText={largeText}
            onLargeTextChange={toggleLargeText}
            onSubPageChange={setNavHidden}
          />
        ) : null}
      </main>
      <div className={`bottom-nav-float${navHidden ? ' nav-hidden' : ''}${navCompact && !navHidden ? ' nav-compact' : ''}`}>
        <nav
          ref={navRef}
          className="bottom-nav"
          aria-label="主导航"
          data-active={tab}
          onPointerDown={onNavPointerDown}
          onPointerMove={onNavPointerMove}
          onPointerUp={endNavDrag}
          onPointerCancel={endNavDrag}
        >
        {/* 底层：中性色 Tab 列表（可交互实体按钮） */}
        <button
          type="button"
          className={tab === 'work' ? 'nav-button active' : 'nav-button'}
          aria-current={tab === 'work' ? 'page' : undefined}
          onClick={() => switchTab('work')}
        >
          <span className="nav-icon"><CalendarDays size={21} /></span>
          记工
        </button>
        {HOURS_ONLY ? null : (
        <button
          type="button"
          className={tab === 'ledger' ? 'nav-button active' : 'nav-button'}
          aria-current={tab === 'ledger' ? 'page' : undefined}
          onClick={() => switchTab('ledger')}
        >
          <span className="nav-icon"><WalletCards size={21} /></span>
          记账
        </button>
        )}
        <button
          type="button"
          className={tab === 'mine' ? 'nav-button active' : 'nav-button'}
          aria-current={tab === 'mine' ? 'page' : undefined}
          onClick={() => switchTab('mine')}
        >
          <span className="nav-icon"><User size={21} /></span>
          我的
        </button>
        {/* 顶层高亮列表：与底层完全重叠，品牌色渲染；
            复用 .nav-button 保证几何逐像素对齐（否则两层文字重影）。
            由 JS 按透镜窗口实时 clip-path 裁剪 —— 滑块滑过哪里，
            哪里的图标文字局部变色并轻微放大。不可聚焦、不参与交互。 */}
        <div
          className="nav-tint"
          aria-hidden="true"
          style={{
            clipPath: `inset(0 calc(100% - ${activeClip.right}px) 0 ${activeClip.left}px round 999px)`,
          }}
        >
          {tabOrder.map((item) => (
            <span key={item} className="nav-button">
              <span className="nav-icon">
                {item === 'work' ? <CalendarDays size={21} /> : item === 'ledger' ? <WalletCards size={21} /> : <User size={21} />}
              </span>
              {item === 'work' ? '记工' : item === 'ledger' ? '记账' : '我的'}
            </span>
          ))}
        </div>
        {/* 双 lens 液态滑动：
            主 lens 从旧位置（lensStart）流到新位置（tabIndex），平移+形变；
            离场 lens 在旧位置收缩淡出，补足"前一个自然流到这边"的观感 */}
        <span
          key={`main-${tab}`}
          className={`liquid-nav-lens lens-morph${dragX !== null ? ' dragging' : ''}`}
          style={{
            '--lens-index': tabIndex[tab],
            '--lens-start': tabIndex[lensFrom],
            ...(dragX !== null
              ? {
                  left: `${dragX}px`,
                  width: `calc((100% - 10px) / ${navCols})`,
                  transform: 'translateX(-50%) scale(1.16, 1.22)',
                }
              : {}),
          } as CSSProperties}
          aria-hidden="true"
        />
        {lensFrom !== tab && dragX === null ? (
          <span
            className="liquid-nav-lens lens-exit"
            style={{ '--lens-index': tabIndex[lensFrom] } as CSSProperties}
            aria-hidden="true"
          />
        ) : null}
        </nav>
      </div>
      {exitHint ? (
        <p className="exit-hint" role="status">
          {exitHint}
        </p>
      ) : null}
      {/* Liquid Glass 折射滤镜：预计算的边缘位移贴图（中心中性、边缘沿法线弯曲）。
          Chromium backdrop-filter url() 官方手法；像素单位，各引擎解释一致 */}
      <svg width="0" height="0" aria-hidden="true" focusable="false" style={{ position: 'absolute' }}>
        <defs>
          <filter id="lg-refract" x="0%" y="0%" width="100%" height="100%" filterUnits="objectBoundingBox">
            <feImage href="glass-refraction-map.png" x="0" y="0" width="272" height="60" result="displacement_map" preserveAspectRatio="none" />
            <feDisplacementMap in="SourceGraphic" in2="displacement_map" scale="17" xChannelSelector="R" yChannelSelector="G" />
          </filter>
          <filter id="lg-lens" x="0%" y="0%" width="100%" height="100%" filterUnits="objectBoundingBox">
            <feImage href="glass-lens-map.png" x="0" y="0" width="88" height="52" result="lens_map" preserveAspectRatio="none" />
            <feDisplacementMap in="SourceGraphic" in2="lens_map" scale="13" xChannelSelector="R" yChannelSelector="G" />
          </filter>
          {/* 拖拽液态透镜：湍流噪声置换（scale 6），边缘产生水滴光学抖动 */}
          <filter id="liquid-lens" x="-20%" y="-20%" width="140%" height="140%">
            <feTurbulence type="fractalNoise" baseFrequency="0.01 0.02" numOctaves="2" seed="11" result="noise" />
            <feDisplacementMap in="SourceGraphic" in2="noise" scale="6" xChannelSelector="R" yChannelSelector="G" />
          </filter>
        </defs>
      </svg>
    </div>
  )
}

export default App
