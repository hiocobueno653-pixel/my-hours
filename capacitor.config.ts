import type { CapacitorConfig } from '@capacitor/cli'

// VITE_HOURS_ONLY=1 → 「只记工时」变体（appId 由 Android flavor 后缀 .hours 区分）
const hoursOnly = process.env.VITE_HOURS_ONLY === '1'

const config: CapacitorConfig = {
  appId: hoursOnly ? 'com.myhours.app.hours' : 'com.myhours.app',
  appName: hoursOnly ? '时页·工时' : '时页',
  webDir: hoursOnly ? 'dist-hours' : 'dist',
  backgroundColor: '#F4F6FB',
  plugins: {
    App: {
      disableBackButtonHandler: false,
    },
    SystemBars: {
      insetsHandling: 'css',
      style: 'LIGHT',
      hidden: false,
    },
  },
  server: {
    androidScheme: 'https',
  },
}

export default config
