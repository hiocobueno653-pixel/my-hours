/**
 * 布局审计：在手机视口下打开应用各页面，量化检测
 *  - 横向溢出（scrollWidth > clientWidth）
 *  - 元素越出视口
 *  - 文本被截断（无 ellipsis 的溢出文本）
 * 用法：node scripts/layout-audit.mjs
 */
import { chromium } from 'playwright-core'

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
const BASE = 'http://localhost:4173/'
const VIEWPORTS = [
  { name: 'phone-360', width: 360, height: 740 },
  { name: 'phone-320', width: 320, height: 640 },
]

function auditFn() {
  const vw = window.innerWidth
  const vh = window.innerHeight
  const issues = []
  const seen = new Set()
  const all = Array.from(document.querySelectorAll('*'))
  for (const el of all) {
    if (seen.has(el)) continue
    seen.add(el)
    const tag = el.tagName.toLowerCase()
    if (['html', 'body', 'script', 'style', 'svg', 'path', 'title'].includes(tag)) continue
    const cs = getComputedStyle(el)
    if (cs.display === 'none' || cs.visibility === 'hidden') continue
    const rect = el.getBoundingClientRect()
    if (rect.width === 0 && rect.height === 0) continue
    if (el.scrollWidth > el.clientWidth + 1 && cs.overflowX === 'visible') {
      issues.push({
        type: 'h-overflow',
        sel: el.id ? '#' + el.id : el.className && typeof el.className === 'string' ? '.' + el.className.split(' ').join('.') : tag,
        tag,
        scrollW: el.scrollWidth,
        clientW: el.clientWidth,
      })
    }
    if (cs.position !== 'fixed' && (rect.right > vw + 1 || rect.left < -1)) {
      issues.push({
        type: 'out-of-viewport',
        sel: el.id ? '#' + el.id : el.className && typeof el.className === 'string' ? '.' + el.className.split(' ').join('.') : tag,
        tag,
        left: Math.round(rect.left),
        right: Math.round(rect.right),
        vw,
      })
    }
    if (el.children.length === 0 && el.textContent.trim()) {
      const sw = el.scrollWidth
      const cw = el.clientWidth
      if (sw > cw + 2 && cs.overflow === 'visible') {
        issues.push({
          type: 'text-overflow',
          sel: el.id ? '#' + el.id : el.className && typeof el.className === 'string' ? '.' + el.className.split(' ').join('.') : tag,
          tag,
          text: el.textContent.trim().slice(0, 24),
          sw,
          cw,
        })
      }
    }
  }
  return { vw, vh, docScrollW: document.documentElement.scrollWidth, issues }
}

async function auditPage(page, viewport) {
  await page.setViewportSize({ width: viewport.width, height: viewport.height })
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.waitForTimeout(900)
  const results = {}
  results.work = await page.evaluate(auditFn)
  await page.click('nav button:nth-child(2)')
  await page.waitForTimeout(700)
  results.ledger = await page.evaluate(auditFn)
  await page.click('nav button:nth-child(3)')
  await page.waitForTimeout(700)
  results.mine = await page.evaluate(auditFn)
  await page.click('nav button:nth-child(1)')
  await page.waitForTimeout(600)
  const todayBtn = await page.locator('.today-action').first()
  if (await todayBtn.count()) {
    await todayBtn.click()
    await page.waitForTimeout(600)
    results.editor = await page.evaluate(auditFn)
  }
  return results
}

for (const vp of VIEWPORTS) {
  const browser = await chromium.launch({ executablePath: CHROME, headless: true })
  const page = await browser.newPage()
  try {
    const results = await auditPage(page, vp)
    console.log(`\n========== ${vp.name} (${vp.width}x${vp.height}) ==========`)
    for (const [area, data] of Object.entries(results)) {
      const issues = data.issues
      console.log(`--- ${area}: docScrollW=${data.docScrollW} vw=${data.vw} issues=${issues.length}`)
      for (const i of issues.slice(0, 25)) {
        console.log(`  [${i.type}] ${i.sel} (${i.tag})` + (i.text ? ` "${i.text}"` : '') + (i.scrollW ? ` sw=${i.scrollW}/cw=${i.clientW ?? i.cw}` : '') + (i.right ? ` right=${i.right}` : ''))
      }
      if (issues.length > 25) console.log(`  ... 共 ${issues.length} 条`)
    }
  } finally {
    await browser.close()
  }
}