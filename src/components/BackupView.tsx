import { CloudUpload, FileDown, FileUp } from 'lucide-react'
import { useRef, useState } from 'react'
import { parseBackupText } from '../data/backup'
import { exportBackupFile } from '../services/exportService'
import { ConfirmDialog } from './ConfirmDialog'
import type { ParsedBackupData } from '../data/types'
import { useAppStore } from '../store/useAppStore'

interface BackupViewProps {
  compact?: boolean
}

export function BackupView({ compact = false }: BackupViewProps) {
  const records = useAppStore((state) => state.records)
  const entries = useAppStore((state) => state.entries)
  const customCategories = useAppStore((state) => state.customCategories)
  const replaceAll = useAppStore((state) => state.replaceAll)
  const inputRef = useRef<HTMLInputElement>(null)
  const [message, setMessage] = useState('')
  const [pendingImport, setPendingImport] = useState<ParsedBackupData | null>(null)

  const handleExport = async () => {
    setMessage('导出中')
    try {
      await exportBackupFile(records, entries, customCategories)
      setMessage('数据备份已保存')
    } catch {
      setMessage('导出失败')
    }
  }

  const handleImport = async (file: File) => {
    try {
      const next = parseBackupText(await file.text())
      setPendingImport(next)
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '导入失败')
    }
  }

  const handleImportConfirm = () => {
    if (!pendingImport) return
    replaceAll(pendingImport)
    setPendingImport(null)
    setMessage('备份已导入')
  }

  return (
    <div className={`backup-view${compact ? ' backup-view-compact' : ''}`}>
      {!compact ? (
        <header className="page-header">
          <h2>备份</h2>
        </header>
      ) : null}

      <section className="panel backup-panel">
        <div className="backup-stats">
          <div className="backup-stat">
            <span>工时记录</span>
            <strong>{records.length}</strong>
            <small>天</small>
          </div>
          <div className="backup-stat">
            <span>账目记录</span>
            <strong>{entries.length}</strong>
            <small>笔</small>
          </div>
          <div className="backup-stat">
            <span>自定义分类</span>
            <strong>{customCategories.length}</strong>
            <small>个</small>
          </div>
        </div>
        <button
          type="button"
          className="button primary full"
          onClick={handleExport}
        >
          <FileDown size={18} />
          保存数据备份
        </button>
        <p className="backup-note">
          <CloudUpload size={16} />
          手机上的文件可通过系统分享保存到小米云盘、OPPO 云服务或其他云盘
        </p>
        <button
          type="button"
          className="button full"
          onClick={() => inputRef.current?.click()}
        >
          <FileUp size={18} />
          加载备份数据
        </button>
        <input
          ref={inputRef}
          className="visually-hidden"
          type="file"
          accept=".json,application/json"
          onChange={(event) => {
            const file = event.currentTarget.files?.[0]
            if (file) void handleImport(file)
            event.currentTarget.value = ''
          }}
        />
      </section>

      {message ? (
        <p className="status-line" role="status">
          {message}
        </p>
      ) : null}

      {pendingImport ? (
        <ConfirmDialog
          title="导入备份？"
          message="导入会替换当前全部工时、账目和自定义分类。"
          confirmLabel="导入"
          onConfirm={handleImportConfirm}
          onCancel={() => setPendingImport(null)}
        />
      ) : null}
    </div>
  )
}
