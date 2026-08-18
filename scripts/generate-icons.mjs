import { mkdir, access, writeFile } from 'node:fs/promises'
import path from 'node:path'
import sharp from 'sharp'

const root = process.cwd()
const publicDir = path.join(root, 'public')
const candidateDir = path.join(root, 'public', 'icons', 'candidates')
const ICON_SIZE = 1024
// Android's guaranteed adaptive-icon safe zone is 66dp inside a 108dp layer.
const ADAPTIVE_CONTENT_RATIO = 66 / 108
const TRANSPARENT = { r: 0, g: 0, b: 0, alpha: 0 }
const WHITE = { r: 255, g: 255, b: 255, alpha: 1 }

// The supplied artwork contains a generator watermark in the lower-right
// corner. Keep the artwork itself, but crop the empty watermark strip before
// it is used as the app icon. The subject and its shadow end well above this
// line, so the resulting crop does not cut the illustrated mark.
const CUSTOM_ARTWORK_CONTENT_HEIGHT = 925

const candidates = [
  {
    file: 'candidate-1.png',
    background: '#0F766E',
    top: '#0B5E57',
    body: '#FFFFFF',
    check: '#16A34A',
    ring: '#0F766E',
  },
  {
    file: 'candidate-2.png',
    background: '#2563EB',
    top: '#1D4ED8',
    body: '#F8FAFC',
    check: '#16A34A',
    ring: '#2563EB',
  },
  {
    file: 'candidate-3.png',
    background: '#334155',
    top: '#1E293B',
    body: '#F1F5F9',
    check: '#F59E0B',
    ring: '#334155',
  },
]

function calendarMark(colors) {
  return `
    <rect x="180" y="260" width="664" height="520" rx="90" fill="${colors.body}"/>
    <path d="M180 360h664v-10a90 90 0 0 0-90-90H270a90 90 0 0 0-90 90v10z" fill="${colors.top}"/>
    <circle cx="330" cy="300" r="30" fill="${colors.ring}"/>
    <circle cx="474" cy="300" r="30" fill="${colors.ring}"/>
    <circle cx="618" cy="300" r="30" fill="${colors.ring}"/>
    <path d="M360 530l110 110 220-250" fill="none" stroke="${colors.check}" stroke-width="64" stroke-linecap="round" stroke-linejoin="round"/>
  `
}

function fullIconSvg(colors) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
    <rect x="0" y="0" width="1024" height="1024" fill="${colors.background}"/>
    ${calendarMark(colors)}
  </svg>`
}

function foregroundSvg(colors) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
    <g transform="translate(170 170) scale(0.68)">
      ${calendarMark(colors)}
    </g>
  </svg>`
}

const monochromeResource = `<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#000000"
        android:pathData="M31,22h46c8.28,0 15,6.72 15,15v34c0,8.28 -6.72,15 -15,15H31c-8.28,0 -15,-6.72 -15,-15V37c0,-8.28 6.72,-15 15,-15z" />
    <path
        android:fillColor="#000000"
        android:pathData="M31,22h46c8.28,0 15,6.72 15,15v8H16v-8c0,-8.28 6.72,-15 15,-15z" />
    <path
        android:fillColor="#000000"
        android:pathData="M35,18h4v12h-4zM69,18h4v12h-4z" />
    <path
        android:fillColor="#000000"
        android:pathData="M35,60a19,19 0,1 1,5.6 13.4l4.3,-4.3A13,13 0,1 0,41,60h-6z" />
    <path
        android:fillColor="#000000"
        android:pathData="M54,58l18,-12 -12,18z" />
</vector>
`

async function writeMonochromeResource(resDir) {
  const filePath = path.join(resDir, 'drawable', 'ic_launcher_monochrome.xml')
  await mkdir(path.dirname(filePath), { recursive: true })
  await writeFile(filePath, monochromeResource, 'utf8')
}

async function writeAdaptiveIconResources(resDir) {
  const adaptiveIcon = `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
`
  const adaptiveDir = path.join(resDir, 'mipmap-anydpi-v26')
  await mkdir(adaptiveDir, { recursive: true })
  await writeFile(path.join(adaptiveDir, 'ic_launcher.xml'), adaptiveIcon, 'utf8')
  await writeFile(path.join(adaptiveDir, 'ic_launcher_round.xml'), adaptiveIcon, 'utf8')
}

async function writePng(svg, size, filePath) {
  await mkdir(path.dirname(filePath), { recursive: true })
  await sharp(Buffer.from(svg)).resize(size, size).png().toFile(filePath)
}

async function prepareCustomArtwork(sourcePath) {
  // Normalize to a square first so every density is generated from exactly
  // the same crop. The final 99px are intentionally replaced with white to
  // remove the watermark that is present in the supplied image.
  const cleanHeight = Math.min(CUSTOM_ARTWORK_CONTENT_HEIGHT, ICON_SIZE)
  return sharp(sourcePath)
    .rotate()
    .resize(ICON_SIZE, ICON_SIZE, { fit: 'cover', position: 'center' })
    .extract({ left: 0, top: 0, width: ICON_SIZE, height: cleanHeight })
    .extend({
      top: 0,
      right: 0,
      bottom: ICON_SIZE - cleanHeight,
      left: 0,
      background: WHITE,
    })
    .png()
    .toBuffer()
}

function isExteriorBackground(data, offset) {
  const r = data[offset]
  const g = data[offset + 1]
  const b = data[offset + 2]
  const min = Math.min(r, g, b)
  const max = Math.max(r, g, b)
  // The artwork has a white page and cream highlights. Restricting the flood
  // fill to low-saturation near-white pixels keeps those highlights intact.
  return min >= 210 && max - min <= 16
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
    if (!isExteriorBackground(data, offset)) return
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

  return sharp(data, {
    raw: { width, height, channels: 4 },
  })
    .png()
    .toBuffer()
}

async function writeImagePng(input, size, filePath) {
  await mkdir(path.dirname(filePath), { recursive: true })
  await sharp(input)
    .resize(size, size, { fit: 'cover', position: 'center' })
    .png()
    .toFile(filePath)
}

async function writeAdaptiveForeground(input, size, filePath) {
  const contentSize = Math.max(1, Math.round(size * ADAPTIVE_CONTENT_RATIO))
  const before = Math.floor((size - contentSize) / 2)
  const after = size - contentSize - before
  const transparentArtwork = await removeExteriorBackground(input)
  const content = await sharp(transparentArtwork)
    .trim({ background: TRANSPARENT, threshold: 4 })
    .resize(contentSize, contentSize, {
      fit: 'contain',
      position: 'center',
      background: TRANSPARENT,
    })
    .png()
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

async function imageBackgroundColor(input) {
  const { data } = await sharp(input)
    .extract({ left: 0, top: 0, width: 1, height: 1 })
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true })
  const [r, g, b] = data
  const hex = [r, g, b]
    .map((value) => value.toString(16).padStart(2, '0'))
    .join('')
  return `#${hex}`
}

async function generateCandidates() {
  await mkdir(candidateDir, { recursive: true })
  for (const candidate of candidates) {
    await writePng(fullIconSvg(candidate), ICON_SIZE, path.join(candidateDir, candidate.file))
  }
  console.log(`generated ${candidates.length} icon candidates in ${candidateDir}`)
}

async function generateAndroidIcons(sourceName) {
  const candidate = candidates.find((item) => sourceName.includes(item.file))
  if (!candidate) {
    throw new Error(`unknown candidate: ${sourceName}`)
  }
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
    await writePng(fullIconSvg(candidate), legacySize, path.join(mipmapDir, 'ic_launcher.png'))
    await writePng(fullIconSvg(candidate), legacySize, path.join(mipmapDir, 'ic_launcher_round.png'))
    await writePng(foregroundSvg(candidate), foregroundSize, path.join(mipmapDir, 'ic_launcher_foreground.png'))
  }
  await writeMonochromeResource(resDir)
  await writeAdaptiveIconResources(resDir)
  const colorsFile = path.join(resDir, 'values', 'ic_launcher_background.xml')
  await mkdir(path.dirname(colorsFile), { recursive: true })
  const colorXml = `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">${candidate.background}</color>\n</resources>\n`
  await writeFile(colorsFile, colorXml, 'utf8')
  console.log(`wrote Android icons for ${candidate.file}`)
}

async function generateCustomAndroidIcons(sourcePath) {
  const resDir = path.join(root, 'android', 'app', 'src', 'main', 'res')
  const sizes = [
    ['mdpi', 48, 108],
    ['hdpi', 72, 162],
    ['xhdpi', 96, 216],
    ['xxhdpi', 144, 324],
    ['xxxhdpi', 192, 432],
  ]

  const artwork = await prepareCustomArtwork(sourcePath)
  await writeImagePng(artwork, ICON_SIZE, path.join(publicDir, 'app-icon.png'))
  for (const [density, legacySize, foregroundSize] of sizes) {
    const mipmapDir = path.join(resDir, `mipmap-${density}`)
    await writeImagePng(artwork, legacySize, path.join(mipmapDir, 'ic_launcher.png'))
    await writeImagePng(artwork, legacySize, path.join(mipmapDir, 'ic_launcher_round.png'))
    await writeAdaptiveForeground(
      artwork,
      foregroundSize,
      path.join(mipmapDir, 'ic_launcher_foreground.png'),
    )
  }

  await writeMonochromeResource(resDir)
  await writeAdaptiveIconResources(resDir)
  const colorsFile = path.join(resDir, 'values', 'ic_launcher_background.xml')
  await mkdir(path.dirname(colorsFile), { recursive: true })
  const backgroundColor = await imageBackgroundColor(artwork)
  const colorXml = `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">${backgroundColor}</color>\n</resources>\n`
  await writeFile(colorsFile, colorXml, 'utf8')
  console.log(`wrote Android icons from ${sourcePath}`)
}

const sourceArg = process.argv.find((arg) => arg.startsWith('--source='))
if (sourceArg) {
  const sourceName = sourceArg.slice('--source='.length)
  if (sourceName.includes('candidate-')) {
    await generateAndroidIcons(sourceName)
  } else {
    await generateCustomAndroidIcons(path.resolve(root, sourceName))
  }
} else {
  await generateCandidates()
  const defaultSource = path.join(publicDir, 'app-icon.jpg')
  let hasDefaultSource = true
  try {
    await access(defaultSource)
  } catch {
    hasDefaultSource = false
  }
  if (hasDefaultSource) {
    await generateCustomAndroidIcons(defaultSource)
  } else {
    console.warn(`custom icon source not found at ${defaultSource}`)
  }
}
