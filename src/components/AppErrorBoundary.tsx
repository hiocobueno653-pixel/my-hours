import { Component, type ReactNode } from 'react'
import { useAppStore } from '../store/useAppStore'

interface AppErrorBoundaryProps {
  children: ReactNode
}

interface AppErrorBoundaryState {
  error: Error | null
}

/** 顶层错误边界：任何渲染异常兜底为可恢复界面，避免整屏白死。
    恢复路径：重试 / 导出全部原始数据（用于排查或迁移）/ 清空数据重置。 */
export class AppErrorBoundary extends Component<
  AppErrorBoundaryProps,
  AppErrorBoundaryState
> {
  state: AppErrorBoundaryState = { error: null }

  static getDerivedStateFromError(error: Error): AppErrorBoundaryState {
    return { error }
  }

  componentDidCatch(error: Error): void {
    console.error('[my-hours] 界面渲染异常', error)
  }

  private handleRetry = (): void => {
    this.setState({ error: null })
  }

  private handleExport = (): void => {
    try {
      const dump: Record<string, unknown> = {}
      for (let index = 0; index < window.localStorage.length; index += 1) {
        const key = window.localStorage.key(index)
        if (key?.startsWith('my-hours.')) {
          dump[key] = window.localStorage.getItem(key)
        }
      }
      const blob = new Blob([JSON.stringify(dump, null, 2)], {
        type: 'application/json',
      })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      const now = new Date()
      const stamp = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}`
      link.href = url
      link.download = `时账-诊断数据-${stamp}.json`
      link.click()
      URL.revokeObjectURL(url)
    } catch (exportError) {
      console.error('[my-hours] 诊断数据导出失败', exportError)
    }
  }

  private handleReset = (): void => {
    const confirmed = window.confirm('将清空全部工时与账目数据并重置应用，操作不可撤销。建议先导出诊断数据。确定继续？')
    if (!confirmed) return
    try {
      // 走 store 的 clearAll：清空主数据 + 自动备份（IndexedDB/文件系统），
      // 并写入抑制标志，避免重载后自动恢复把旧数据拉回来
      useAppStore.getState().clearAll()
    } catch (resetError) {
      console.error('[my-hours] 数据重置失败', resetError)
    }
    window.location.reload()
  }

  render(): ReactNode {
    const { error } = this.state
    if (!error) return this.props.children
    return (
      <div
        role="alert"
        style={{
          minHeight: '100dvh',
          margin: '0 auto',
          maxWidth: 420,
          padding: '48px 20px',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 12,
          textAlign: 'center',
          fontFamily: 'inherit',
          color: '#111113',
          background: '#f4f6fb',
        }}
      >
        <h1 style={{ margin: 0, fontSize: 20, fontWeight: 800 }}>界面出了点问题</h1>
        <p style={{ margin: 0, fontSize: 14, color: '#5c5c62', lineHeight: 1.6 }}>
          数据一般没有丢失。可先重试；仍然异常时，建议导出诊断数据后重置应用。
        </p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, width: '100%', marginTop: 12 }}>
          <button
            type="button"
            onClick={this.handleRetry}
            style={buttonStyle('#0071e3', '#fff')}
          >
            重试
          </button>
          <button
            type="button"
            onClick={this.handleExport}
            style={buttonStyle('#fff', '#111113')}
          >
            导出诊断数据
          </button>
          <button
            type="button"
            onClick={this.handleReset}
            style={buttonStyle('#fff', '#d64545')}
          >
            清空数据并重置
          </button>
        </div>
      </div>
    )
  }
}

function buttonStyle(background: string, color: string): React.CSSProperties {
  return {
    minHeight: 48,
    borderRadius: 12,
    border: '1px solid rgba(17,17,19,0.14)',
    background,
    color,
    fontSize: 16,
    fontWeight: 700,
    cursor: 'pointer',
  }
}
