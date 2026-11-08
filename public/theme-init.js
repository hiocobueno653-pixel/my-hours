/* 首屏主题预设：在任何绘制前设置 data-theme，避免深色模式冷启动闪白。
   由 index.html 以阻塞式经典脚本引用（CSP script-src 'self' 允许同源脚本）。
   与 src/utils/theme.ts 的解析规则保持一致：存储无效时跟随系统。 */
;(function () {
  try {
    var stored = window.localStorage.getItem('my-hours.theme')
    var dark =
      stored === 'dark' ||
      (stored !== 'light' && window.matchMedia('(prefers-color-scheme: dark)').matches)
    document.documentElement.dataset.theme = dark ? 'dark' : 'light'
    var meta = document.querySelector('meta[name="theme-color"]')
    if (meta) meta.setAttribute('content', dark ? '#141414' : '#f4f5f7')
  } catch (error) {
    /* 存储不可用：保持默认浅色 */
  }
})()
