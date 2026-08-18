import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.myhours.app',
  appName: '我的工时',
  webDir: 'dist',
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
