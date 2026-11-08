import { rm } from 'node:fs/promises'
import path from 'node:path'

const root = process.cwd()
const dist = path.join(root, process.env.VITE_HOURS_ONLY === '1' ? 'dist-hours' : 'dist')

// 开发/生成过程中使用的素材（图标候选、参考图、预览）不进入最终安装包。
// 源码 public/ 下保留，仅从构建产物排除。
await rm(path.join(dist, 'icons'), { recursive: true, force: true })
console.log(`已从 ${dist} 移除开发素材 public/icons`)
