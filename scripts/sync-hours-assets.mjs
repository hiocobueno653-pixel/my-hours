/**
 * 将「只记工时」版 Web 构建（dist-hours）分发到 Android hours flavor：
 *  - android/app/src/hours/assets/public/  覆盖 main 的 Web 资产（Gradle flavor 源集优先）
 *  - android/app/src/hours/assets/capacitor.config.json  注入 hours 的应用名/appId
 * 用法：先用 HOURS_ONLY=1 npm run build 产出 dist-hours，再运行本脚本。
 */
import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import path from 'node:path'

const root = process.cwd()
const src = path.join(root, 'dist-hours')
const flavorAssets = path.join(root, 'android', 'app', 'src', 'hours', 'assets')
const destPublic = path.join(flavorAssets, 'public')

if (!process.env.VITE_HOURS_ONLY) {
  console.error('请先执行: $env:VITE_HOURS_ONLY="1"; npm run build（产出 dist-hours）')
  process.exit(1)
}

// 覆盖式复制：先清空目标，避免旧构建的 index-*.js 残留进 APK
await rm(destPublic, { recursive: true, force: true })
await cp(src, destPublic, { recursive: true })
await mkdir(flavorAssets, { recursive: true })

const configPath = path.join(flavorAssets, 'capacitor.config.json')
const config = await readFile(path.join(root, 'android', 'app', 'src', 'main', 'assets', 'capacitor.config.json'), 'utf8')
const patched = config
  .replace(/"appId"\s*:\s*"[^"]*"/, '"appId": "com.myhours.app.hours"')
  .replace(/"appName"\s*:\s*"[^"]*"/, '"appName": "时账·工时"')
  .replace(/"webDir"\s*:\s*"[^"]*"/, '"webDir": "dist-hours"')
await writeFile(configPath, patched, 'utf8')

console.log('已分发 dist-hours → android/app/src/hours/assets/')
