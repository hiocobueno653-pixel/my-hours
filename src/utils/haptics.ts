/** 轻触觉反馈（Android 原生震动；网页端自动忽略） */
export function haptic(pattern: number | number[] = 30): void {
  if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
    try {
      navigator.vibrate(pattern)
    } catch {
      // 不支持或权限受限时静默忽略
    }
  }
}
