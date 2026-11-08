import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { AppErrorBoundary } from './AppErrorBoundary'

let shouldThrow = false

function Bomb(): React.JSX.Element {
  const [tick, setTick] = useState(0)
  if (shouldThrow && tick === 0) {
    setTick(1)
    throw new Error('渲染崩溃')
  }
  return <div>正常内容</div>
}

// React 捕获边界时会向 console 输出错误，测试中静音避免噪音
afterEach(() => {
  shouldThrow = false
  vi.restoreAllMocks()
})

describe('AppErrorBoundary', () => {
  it('renders children when no error occurs', () => {
    render(
      <AppErrorBoundary>
        <div>健康内容</div>
      </AppErrorBoundary>,
    )
    expect(screen.getByText('健康内容')).toBeInTheDocument()
  })

  it('catches render crashes and offers recovery actions', () => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
    shouldThrow = true
    render(
      <AppErrorBoundary>
        <Bomb />
      </AppErrorBoundary>,
    )
    expect(screen.getByRole('alert')).toBeInTheDocument()
    expect(screen.getByText('界面出了点问题')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '重试' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '导出诊断数据' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '清空数据并重置' })).toBeInTheDocument()
  })

  it('recovers to normal content after retry once the fault is gone', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
    shouldThrow = true
    render(
      <AppErrorBoundary>
        <Bomb />
      </AppErrorBoundary>,
    )
    expect(screen.getByText('界面出了点问题')).toBeInTheDocument()

    shouldThrow = false
    await userEvent.click(screen.getByRole('button', { name: '重试' }))
    expect(screen.getByText('正常内容')).toBeInTheDocument()
  })
})
