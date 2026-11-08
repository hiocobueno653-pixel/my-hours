import { useModalLayer } from '../navigation/backNavigation'

interface ConfirmDialogProps {
  title: string
  message: string
  confirmLabel?: string
  cancelLabel?: string
  danger?: boolean
  onConfirm: () => void
  onCancel: () => void
}

export function ConfirmDialog({
  title,
  message,
  confirmLabel = '确认',
  cancelLabel = '取消',
  danger = false,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  const { containerRef, onKeyDown } = useModalLayer(onCancel)

  return (
    <div className="confirm-backdrop" ref={containerRef} onClick={onCancel} onKeyDown={onKeyDown}>
      <section
        className="confirm-dialog"
        role="alertdialog"
        aria-modal="true"
        aria-label={title}
        onClick={(event) => event.stopPropagation()}
      >
        <h2>{title}</h2>
        <p>{message}</p>
        <div className="confirm-actions">
          <button type="button" className="button" onClick={onCancel}>
            {cancelLabel}
          </button>
          <button
            type="button"
            className={`button${danger ? ' danger solid' : ' primary'}`}
            onClick={onConfirm}
          >
            {confirmLabel}
          </button>
        </div>
      </section>
    </div>
  )
}
