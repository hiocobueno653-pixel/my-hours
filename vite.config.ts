import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

// VITE_HOURS_ONLY=1 → 「只记工时」变体：无记账页、不生成工资账本，输出到 dist-hours
// （环境变量同时以 import.meta.env.VITE_HOURS_ONLY 注入源码，vite 构建时静态替换，
//   vitest 未设置时安全默认为完整版路径）
const hoursOnly = process.env.VITE_HOURS_ONLY === '1'

// https://vite.dev/config/
export default defineConfig({
  build: {
    outDir: hoursOnly ? 'dist-hours' : 'dist',
  },
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      injectRegister: 'auto',
      // 玻璃折射滤镜贴图必须随 PWA 预缓存，否则离线时导航滤镜降级
      includeAssets: [
        'app-icon.png',
        'favicon.svg',
        'glass-refraction-map.png',
        'glass-lens-map.png',
      ],
      manifest: {
        name: hoursOnly ? '时账·工时' : '时账',
        short_name: hoursOnly ? '时账工时' : '时账',
        description: hoursOnly
          ? '离线记录工时与工资，按月汇总并支持本地备份。'
          : '离线记录工时和收支，按月汇总并支持本地备份。',
        theme_color: '#f5f5f7',
        background_color: '#f5f5f7',
        display: 'standalone',
        start_url: '/',
        scope: '/',
        lang: 'zh-CN',
        icons: [
          {
            src: '/app-icon.png',
            sizes: 'any',
            type: 'image/png',
            purpose: 'any maskable',
          },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,svg,woff,woff2}'],
        globIgnores: ['**/icons/**', '**/app-icon.jpg'],
        navigateFallback: '/index.html',
        cleanupOutdatedCaches: true,
        clientsClaim: true,
        skipWaiting: true,
      },
    }),
  ],
})
