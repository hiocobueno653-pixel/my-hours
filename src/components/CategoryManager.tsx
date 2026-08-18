import { Plus, Trash2, X } from 'lucide-react'
import { useState } from 'react'
import {
  DEFAULT_LEDGER_CATEGORIES,
  isLedgerCategoryInUse,
  MAX_CATEGORY_NAME_LENGTH,
} from '../data/ledger'
import type { LedgerType } from '../data/types'
import { useAppStore } from '../store/useAppStore'
import { useModalLayer } from '../navigation/backNavigation'

interface CategoryManagerProps {
  initialType?: LedgerType
  onClose: () => void
}

export function CategoryManager({ initialType, onClose }: CategoryManagerProps) {
  useModalLayer(onClose)
  const customCategories = useAppStore((state) => state.customCategories)
  const entries = useAppStore((state) => state.entries)
  const addCustomCategory = useAppStore((state) => state.addCustomCategory)
  const deleteCustomCategory = useAppStore((state) => state.deleteCustomCategory)
  const [type, setType] = useState<LedgerType>(initialType ?? 'expense')
  const [name, setName] = useState('')
  const [message, setMessage] = useState('')

  const customForType = customCategories.filter(
    (category) => category.type === type,
  )

  const handleAdd = () => {
    const added = addCustomCategory(type, name)
    if (!added) {
      setMessage(name.trim() ? '分类已存在或名称无效' : '请输入分类名称')
      return
    }
    setName('')
    setMessage('分类已添加')
  }

  const handleDelete = (id: string) => {
    const deleted = deleteCustomCategory(id)
    setMessage(deleted ? '分类已删除' : '该分类已有账目，不能删除')
  }

  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <section
        className="day-sheet category-sheet"
        role="dialog"
        aria-modal="true"
        aria-label="管理分类"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="sheet-header">
          <h2>管理分类</h2>
          <button type="button" className="icon-button" onClick={onClose} aria-label="关闭">
            <X size={20} />
          </button>
        </div>

        <div className="segmented" aria-label="收支类型">
          <button
            type="button"
            className={type === 'expense' ? 'segment active expense' : 'segment'}
            aria-pressed={type === 'expense'}
            onClick={() => {
              setType('expense')
              setMessage('')
            }}
          >
            支出
          </button>
          <button
            type="button"
            className={type === 'income' ? 'segment active income' : 'segment'}
            aria-pressed={type === 'income'}
            onClick={() => {
              setType('income')
              setMessage('')
            }}
          >
            收入
          </button>
        </div>

        <div className="category-list">
          {DEFAULT_LEDGER_CATEGORIES[type].map((item) => (
            <div className="category-row" key={item}>
              <span>{item}</span>
              <span className="category-kind">默认</span>
            </div>
          ))}
          {customForType.map((category) => {
            const inUse = isLedgerCategoryInUse(
              entries,
              category.type,
              category.name,
            )
            return (
              <div className="category-row" key={category.id}>
                <span>{category.name}</span>
                {inUse ? (
                  <span className="category-kind">使用中</span>
                ) : (
                  <button
                    type="button"
                    className="icon-button small"
                    onClick={() => handleDelete(category.id)}
                    aria-label={`删除分类${category.name}`}
                  >
                    <Trash2 size={16} />
                  </button>
                )}
              </div>
            )
          })}
        </div>

        <div className="category-add-row">
          <input
            value={name}
            maxLength={MAX_CATEGORY_NAME_LENGTH}
            onChange={(event) => {
              setName(event.target.value)
              setMessage('')
            }}
            aria-label="新分类名称"
            placeholder="新分类"
          />
          <button type="button" className="button primary" onClick={handleAdd}>
            <Plus size={18} />
            添加
          </button>
        </div>

        {message ? <p className="status-line">{message}</p> : null}
      </section>
    </div>
  )
}
