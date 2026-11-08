/**
 * 从用户素材生成 App 图标（Web favicon + Android 全套）。
 * 素材特征：浅灰/近白底、深黑+青蓝图形、图形偏下。
 * 流程：去背景(flood fill) → 裁到图形包围盒 → 居中 + 12% 留白 → 白底。
 * 用法：node scripts/generate-app-icon.mjs
 */
import { mkdir, writeFile } from 'node:fs/promises'
import path from 'node:path'
import sharp from 'sharp'

const root = process.cwd()
const publicDir = path.join(root, 'public')
const SOURCE = path.join(publicDir, 'icons', 'user-icon-ref.png')
const ICON_SIZE = 1024
const PADDING_RATIO = 0.12 // 图形四周留白
const ADAPTIVE_CONTENT_RATIO = 66 / 108
const WHITE = { r: 255, g: 255, b: 255, alpha: 1 }
const TRANSPARENT = { r: 0, g: 0, b: 0, alpha: 0 }

// 背景判断：低饱和近白/浅灰（素材底色约 #f0f0f0 ~ #fafafb）
function isBackground(data, offset) {
  const r = data[offset]
  const g = data[offset + 1]
  const b = data[offset + 2]
  const min = Math.min(r, g, b)
  const max = Math.max(r, g, b)
  return min >= 235 && max - min <= 18
}

async function removeExteriorBackground(input) {
  const { data, info } = await sharp(input)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true })
  const { width, height } = info
  const visited = new Uint8Array(width * height)
  const queue = new Int32Array(width * height)
  let head = 0
  let tail = 0

  const enqueue = (x, y) => {
    const index = y * width + x
    if (visited[index]) return
    const offset = index * 4
    if (!isBackground(data, offset)) return
    visited[index] = 1
    queue[tail++] = index
  }

  for (let x = 0; x < width; x += 1) {
    enqueue(x, 0)
    enqueue(x, height - 1)
  }
  for (let y = 1; y < height - 1; y += 1) {
    enqueue(0, y)
    enqueue(width - 1, y)
  }

  while (head < tail) {
    const index = queue[head++]
    const x = index % width
    const y = Math.floor(index / width)
    if (x > 0) enqueue(x - 1, y)
    if (x + 1 < width) enqueue(x + 1, y)
    if (y > 0) enqueue(x, y - 1)
    if (y + 1 < height) enqueue(x, y + 1)
  }

  for (let index = 0; index < visited.length; index += 1) {
    if (visited[index]) data[index * 4 + 3] = 0
  }

  return sharp(data, { raw: { width, height, channels: 4 } })
    .png()
    .toBuffer()
}

/** 生成居中带留白的正方形图标（白底或透明底） */
async function buildIcon(input, size, { background = TRANSPARENT, paddingRatio = PADDING_RATIO } = {}) {
  const transparent = await removeExteriorBackground(input)
  const trimmed = await sharp(transparent)
    .trim({ background: TRANSPARENT, threshold: 8 })
    .toBuffer()
  const meta = await sharp(trimmed).metadata()
  const contentW = meta.width
  const contentH = meta.height
  // 内容放进 size*(1-2*padding) 的区域，居中
  const avail = Math.round(size * (1 - paddingRatio * 2))
  const scale = Math.min(avail / contentW, avail / contentH)
  const targetW = Math.max(1, Math.round(contentW * scale))
  const targetH = Math.max(1, Math.round(contentH * scale))
  const padX = Math.round((size - targetW) / 2)
  const padY = Math.round((size - targetH) / 2)
  const content = await sharp(trimmed)
    .resize(targetW, targetH, { fit: 'fill' })
    .toBuffer()
  return sharp({
    create: { width: size, height: size, channels: 4, background },
  })
    .composite([{ input: content, left: padX, top: padY }])
    .png()
    .toBuffer()
}

async function writePng(buffer, size, filePath) {
  await mkdir(path.dirname(filePath), { recursive: true })
  await sharp(buffer).resize(size, size, { fit: 'fill' }).png().toFile(filePath)
}

async function writeAdaptiveForeground(buffer, size, filePath) {
  const contentSize = Math.max(1, Math.round(size * ADAPTIVE_CONTENT_RATIO))
  const before = Math.floor((size - contentSize) / 2)
  const after = size - contentSize - before
  const content = await sharp(buffer)
    .resize(contentSize, contentSize, { fit: 'fill' })
    .toBuffer()
  await mkdir(path.dirname(filePath), { recursive: true })
  await sharp(content)
    .extend({
      top: before,
      right: after,
      bottom: after,
      left: before,
      background: TRANSPARENT,
    })
    .png()
    .toFile(filePath)
}

// 主流程
const artwork = await buildIcon(SOURCE, ICON_SIZE, { background: WHITE })
await writePng(artwork, ICON_SIZE, path.join(publicDir, 'app-icon.png'))
// 预览图供核对
await writePng(artwork, 256, path.join(publicDir, 'icons', 'icon-preview.png'))

// Android 图标
const resDir = path.join(root, 'android', 'app', 'src', 'main', 'res')
const sizes = [
  ['mdpi', 48, 108],
  ['hdpi', 72, 162],
  ['xhdpi', 96, 216],
  ['xxhdpi', 144, 324],
  ['xxxhdpi', 192, 432],
]
for (const [density, legacySize, foregroundSize] of sizes) {
  const mipmapDir = path.join(resDir, `mipmap-${density}`)
  await writePng(artwork, legacySize, path.join(mipmapDir, 'ic_launcher.png'))
  await writePng(artwork, legacySize, path.join(mipmapDir, 'ic_launcher_round.png'))
  await writeAdaptiveForeground(artwork, foregroundSize, path.join(mipmapDir, 'ic_launcher_foreground.png'))
}
// 背景色（白底 → 白色，Android adaptive 背景与主图白底一致）
const colorsFile = path.join(resDir, 'values', 'ic_launcher_background.xml')
await mkdir(path.dirname(colorsFile), { recursive: true })
const colorXml = `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#FFFFFF</color>\n</resources>\n`
await writeFile(colorsFile, colorXml, 'utf8')

console.log('App 图标已生成: public/app-icon.png + Android 全套 + 预览 public/icons/icon-preview.png')
