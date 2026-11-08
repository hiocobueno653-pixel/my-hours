// 冒烟：验证「只记工时」构建（dist-hours）——无工资/工作/结算 UI + 宽屏双列
import { chromium } from 'playwright-core'

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
const BASE = 'http://localhost:4173/'

const browser = await chromium.launch({ executablePath: CHROME })

// —— 手机视口 ——
const page = await browser.newPage({ viewport: { width: 375, height: 800 } })
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.waitForTimeout(800)

const navTexts = await page.locator('.bottom-nav button').allTextContents()
console.log('NAV:', JSON.stringify(navTexts), navTexts.length === 2 && !navTexts.some(t => t.includes('记账')) ? 'PASS' : 'FAIL')

// 导航 2-Tab 几何：胶囊宽 200、lens 宽一半；点「我的」后 lens 应覆盖按钮
const navBox = await page.locator('.bottom-nav').boundingBox()
console.log('NAV 宽:', navBox.width, Math.abs(navBox.width - 200) < 2 ? 'PASS' : 'FAIL')
const lensBoxBefore = await page.locator('.liquid-nav-lens.lens-morph').boundingBox()
const mineBtn = page.locator('.bottom-nav button', { hasText: '我的' })
await mineBtn.click()
await page.waitForTimeout(700)
const lensBoxAfter = await page.locator('.liquid-nav-lens.lens-morph').boundingBox()
const mineBox = await mineBtn.boundingBox()
const overlap =
  lensBoxAfter && mineBox &&
  Math.abs(lensBoxAfter.x - mineBox.x) < 8 &&
  Math.abs(lensBoxAfter.width - mineBox.width) < 8
console.log('lens 覆盖「我的」:', overlap ? 'PASS' : 'FAIL', JSON.stringify({ lensBoxAfter, mineBox }))
console.log('lens 初始位(记工):', lensBoxBefore, lensBoxBefore && Math.abs(lensBoxBefore.x - navBox.x + 0) < 12 ? 'PASS' : 'CHECK')
await page.screenshot({ path: 'smoke-hours-nav-mine.png' })
// 切回记工，lens 应回到左侧
await page.locator('.bottom-nav button', { hasText: '记工' }).click()
await page.waitForTimeout(700)
const lensBack = await page.locator('.liquid-nav-lens.lens-morph').boundingBox()
const backOk = lensBack && Math.abs(lensBack.x - navBox.x) < 8
console.log('lens 回到「记工」:', backOk ? 'PASS' : 'FAIL', JSON.stringify(lensBack))

const todayLedgerBtn = await page.locator('.today-ledger-button').count()
console.log('今日记一笔按钮:', todayLedgerBtn, todayLedgerBtn === 0 ? 'PASS' : 'FAIL')

const bodyText = await page.locator('body').innerText()
const moneyWords = ['待结算', '时薪', '本日工资', '当日工资', '已结算', '未设时薪', '工作']
const found = moneyWords.filter((w) => bodyText.includes(w))
console.log('工资/工作字样残留:', found.length === 0 ? 'PASS' : 'FAIL ' + JSON.stringify(found))

await page.screenshot({ path: 'smoke-hours-mobile.png' })

// 打开编辑器：应只有 1 个数字输入（工时），无工作下拉
const todayCell = page.locator('.calendar-day.today').first()
await todayCell.click()
await page.waitForTimeout(700)
const spinCount = await page.locator('.day-sheet input[type="number"]').count()
const hasWorkSelect = await page.locator('.day-sheet select').count()
const editorText = await page.locator('.day-sheet').innerText()
console.log('编辑器数字输入:', spinCount, spinCount === 1 ? 'PASS' : 'FAIL')
console.log('工作下拉:', hasWorkSelect, hasWorkSelect === 0 ? 'PASS' : 'FAIL')
console.log('编辑器工资字样残留:', ['时薪', '本日工资', '已结算'].some(w => editorText.includes(w)) ? 'FAIL' : 'PASS')
await page.screenshot({ path: 'smoke-hours-editor.png' })
// 关闭
await page.keyboard.press('Escape')
await page.waitForTimeout(500)

// 我的页：无工资面板/预算
await page.locator('.bottom-nav button', { hasText: '我的' }).click()
await page.waitForTimeout(700)
const mineText = await page.locator('body').innerText()
const mineMoney = ['待结算', '应得工资', '结算', '预算', '目标'].filter(w => mineText.includes(w))
console.log('我的页钱相关残留:', mineMoney.length === 0 ? 'PASS' : 'FAIL ' + JSON.stringify(mineMoney))
await page.screenshot({ path: 'smoke-hours-mine.png' })
await page.close()

// —— 宽屏视口：检查双列 ——
const wide = await browser.newPage({ viewport: { width: 1280, height: 900 } })
await wide.goto(BASE, { waitUntil: 'networkidle' })
await wide.waitForTimeout(800)
const monthBox = await wide.locator('.month-view').boundingBox()
const todayBox = await wide.locator('.today-workspace').boundingBox()
const calBox = await wide.locator('.month-calendar').boundingBox()
const twoCol = todayBox && calBox && Math.abs(todayBox.y - calBox.y) < 40 && calBox.x > todayBox.x
console.log('宽屏双列:', twoCol ? 'PASS' : 'FAIL', JSON.stringify({ monthBox, todayBox, calBox }))
const contentMax = await wide.locator('.main-content').evaluate((el) => getComputedStyle(el).maxWidth)
console.log('宽屏内容限宽:', contentMax, contentMax !== 'none' ? 'PASS' : 'FAIL')
await wide.screenshot({ path: 'smoke-hours-wide.png' })
await wide.close()

console.log('DONE')
await browser.close()
