import { useEffect, useRef, type KeyboardEvent as ReactKeyboardEvent } from 'react'

type BackAction = () => void

interface RegisteredAction {
  id: symbol
  actionRef: { current: BackAction }
  active: boolean
}

const actions: RegisteredAction[] = []
let rootAction: BackAction | null = null
let modalDepth = 0

function removeAction(entry: RegisteredAction): void {
  // Mark the entry before removing it so a callback that is already queued by
  // the Android bridge cannot dispatch a stale action after unmount.
  entry.active = false
  const index = actions.findIndex((item) => item.id === entry.id)
  if (index >= 0) actions.splice(index, 1)
}

function registerActionRef(actionRef: { current: BackAction }): () => void {
  const entry: RegisteredAction = {
    id: Symbol('back-action'),
    actionRef,
    active: true,
  }
  actions.push(entry)
  return () => removeAction(entry)
}

export function registerBackAction(action: BackAction): () => void {
  return registerActionRef({ current: action })
}

export function setRootBackAction(action: BackAction): () => void {
  rootAction = action
  return () => {
    if (rootAction === action) rootAction = null
  }
}

/** Runs the top-most modal action, then falls back to the app-level action. */
export function requestBackNavigation(): boolean {
  // A native back event can arrive while React is committing an unmount. Drop
  // inactive entries before selecting the layer so the root action never wins
  // over a still-visible modal (or invokes a stale callback).
  for (let index = actions.length - 1; index >= 0; index -= 1) {
    if (!actions[index].active) actions.splice(index, 1)
  }

  const top = actions.at(-1)
  if (top?.active) {
    top.actionRef.current()
    return true
  }
  if (rootAction) {
    rootAction()
    return true
  }
  return false
}

/** Whether a modal/sheet currently owns the Android back action. */
export function hasModalBackAction(): boolean {
  return actions.some((entry) => entry.active)
}

export function useBackDismiss(onDismiss: BackAction, active = true): void {
  const actionRef = useRef(onDismiss)
  actionRef.current = onDismiss

  useEffect(() => {
    if (!active) return undefined
    return registerActionRef(actionRef)
  }, [active])
}

export function useModalLayer(
  onDismiss: BackAction,
  active = true,
): { containerRef: React.RefObject<HTMLDivElement | null>; onKeyDown: (event: ReactKeyboardEvent) => void } {
  useBackDismiss(onDismiss, active)

  const containerRef = useRef<HTMLDivElement | null>(null)
  const previousFocusRef = useRef<HTMLElement | null>(null)

  // Escape 关闭：弹层打开时注册，浅层弹层不会被深层同时消费
  useEffect(() => {
    if (!active) return undefined
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault()
        onDismiss()
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [active, onDismiss])

  // 打开时记录当前焦点并移入弹层；关闭时恢复
  useEffect(() => {
    if (!active) return undefined
    previousFocusRef.current =
      document.activeElement instanceof HTMLElement ? document.activeElement : null
    const container = containerRef.current
    const focusable = container?.querySelector<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
    )
    focusable?.focus()
    return () => {
      previousFocusRef.current?.focus?.()
      previousFocusRef.current = null
    }
  }, [active])

  // Tab 焦点陷阱：只允许在弹层内循环
  const onKeyDown = (event: ReactKeyboardEvent) => {
    if (event.key !== 'Tab') return
    const container = containerRef.current
    if (!container) return
    const focusable = Array.from(
      container.querySelectorAll<HTMLElement>(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
      ),
    ).filter((el) => !el.hasAttribute('disabled') && el.offsetParent !== null)
    if (focusable.length === 0) return
    const first = focusable[0]
    const last = focusable[focusable.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  useEffect(() => {
    if (!active) return undefined
    modalDepth += 1
    document.body.classList.add('modal-open')
    return () => {
      modalDepth = Math.max(0, modalDepth - 1)
      if (modalDepth === 0) document.body.classList.remove('modal-open')
    }
  }, [active])

  return { containerRef, onKeyDown }
}
