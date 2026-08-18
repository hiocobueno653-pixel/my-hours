import { useEffect, useRef } from 'react'

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

export function useModalLayer(onDismiss: BackAction, active = true): void {
  useBackDismiss(onDismiss, active)

  useEffect(() => {
    if (!active) return undefined
    modalDepth += 1
    document.body.classList.add('modal-open')
    return () => {
      modalDepth = Math.max(0, modalDepth - 1)
      if (modalDepth === 0) document.body.classList.remove('modal-open')
    }
  }, [active])
}
