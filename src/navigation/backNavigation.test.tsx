import { act, render } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  hasModalBackAction,
  registerBackAction,
  requestBackNavigation,
  useBackDismiss,
  useModalLayer,
} from './backNavigation'

function HookLayer({
  onDismiss,
  active = true,
}: {
  onDismiss: () => void
  active?: boolean
}) {
  useBackDismiss(onDismiss, active)
  return null
}

function ModalHookLayer({
  onDismiss,
  active = true,
}: {
  onDismiss: () => void
  active?: boolean
}) {
  useModalLayer(onDismiss, active)
  return null
}

afterEach(() => {
  // The test harness should never leave a layer registered. This also makes
  // failures easier to diagnose without leaking state into the next case.
  expect(hasModalBackAction()).toBe(false)
  document.body.classList.remove('modal-open')
})

describe('back navigation stack', () => {
  it('dispatches the most recently registered layer first', () => {
    const first = vi.fn()
    const second = vi.fn()
    const unregisterFirst = registerBackAction(first)
    const unregisterSecond = registerBackAction(second)

    expect(requestBackNavigation()).toBe(true)
    expect(second).toHaveBeenCalledOnce()
    expect(first).not.toHaveBeenCalled()

    unregisterSecond()
    expect(requestBackNavigation()).toBe(true)
    expect(first).toHaveBeenCalledOnce()

    unregisterFirst()
    expect(requestBackNavigation()).toBe(false)
  })

  it('ignores a layer after it is unregistered', () => {
    const dismiss = vi.fn()
    const unregister = registerBackAction(dismiss)
    unregister()

    expect(hasModalBackAction()).toBe(false)
    expect(requestBackNavigation()).toBe(false)
    expect(dismiss).not.toHaveBeenCalled()
  })

  it('keeps the modal layer above the app root action', () => {
    const root = vi.fn()
    const modal = vi.fn()
    const unregisterRoot = registerBackAction(root)
    const unregisterModal = registerBackAction(modal)

    expect(requestBackNavigation()).toBe(true)
    expect(modal).toHaveBeenCalledOnce()
    expect(root).not.toHaveBeenCalled()

    unregisterModal()
    unregisterRoot()
  })

  it('registers and unregisters hook layers across mount state changes', () => {
    const dismiss = vi.fn()
    const view = render(<HookLayer onDismiss={dismiss} />)

    expect(hasModalBackAction()).toBe(true)
    act(() => requestBackNavigation())
    expect(dismiss).toHaveBeenCalledOnce()

    view.rerender(<HookLayer onDismiss={dismiss} active={false} />)
    expect(hasModalBackAction()).toBe(false)
    expect(requestBackNavigation()).toBe(false)
    view.unmount()
  })

  it('tracks body modal state for nested modal layers', () => {
    const first = render(
      <ModalHookLayer onDismiss={vi.fn()} />,
    )
    expect(document.body).toHaveClass('modal-open')

    const second = render(
      <ModalHookLayer onDismiss={vi.fn()} />,
    )
    second.unmount()
    expect(document.body).toHaveClass('modal-open')

    first.unmount()
    expect(document.body).not.toHaveClass('modal-open')
  })
})
