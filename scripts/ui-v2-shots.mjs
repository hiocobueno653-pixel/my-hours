/** v2 视觉验证截图：工作页(Bento+Dock+页头)、导出玻璃菜单、确认弹窗、深色模式 */
import { chromium } from 'playwright-core'
import { mkdirSync } from 'node:fs'

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
const BASE = process.env.MY_HOURS_BASE ?? 'http://localhost:4173/'
const OUT = process.argv[2] ?? 'ui-v2-shots'
mkdirSync(OUT, { recursive: true })

const seed = () => {
  const recs = []
  for (let d = 1; d <= 24; d += 1) {
    const date = `2026-10-${String(d).padStart(2, '0')}`
    const wd = new Date(`${date}T00:00:00`).getDay()
    if (wd === 0) continue
    if (wd === 6 && d % 2 === 0) continue
    recs.push({ date, hours: d === 21 ? 4 : 7.5 + (d % 3) * 0.5, remark: d % 5 === 0 ? '加班到九点' : '', rate: 25, settled: d <= 15 })
  }
  const entries = recs.filter((r) => r.settled).map((r) => ({
    id: `wage-${r.date}`, date: r.date, type: 'income',
    amount: Math.round(r.hours * 25 * 100) / 100, category: '工资', remark: '结算工资', workDate: r.date,
  }))
  entries.push({ id: 'e1', date: '2026-10-24', type: 'expense', amount: 18.5, category: '餐饮', remark: '午饭' })
  localStorage.setItem('my-hours.data.v1', JSON.stringify({ __v: 1, data: recs }))
  localStorage.setItem('my-hours.ledger.v1', JSON.stringify({ __v: 1, data: entries }))
  localStorage.setItem('my-hours.workProfiles.v1', JSON.stringify({ __v: 1, data: [{ id: 'work-default', name: '默认工作', hourlyRate: 25 }] }))
  localStorage.setItem('my-hours.budget.v1', JSON.stringify({ __v: 1, data: { monthlyExpenseBudget: 2000, monthlyIncomeGoal: 6000 } }))
}

const browser = await chromium.launch({ executablePath: CHROME, headless: true })
for (const theme of ['light', 'dark']) {
  const page = await browser.newPage({ viewport: { width: 360, height: 740 } })
  await page.addInitScript((mode) => { localStorage.setItem('my-hours.theme', mode) }, theme)
  await page.addInitScript(seed)
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.waitForTimeout(1300)
  await page.screenshot({ path: `${OUT}/${theme}-work.png`, fullPage: false })

  // 导出玻璃菜单
  await page.locator('[aria-label="导出工时表"]').click()
  await page.waitForTimeout(600)
  await page.screenshot({ path: `${OUT}/${theme}-menu.png` })
  await page.keyboard.press('Escape')
  await page.waitForTimeout(400)

  // 删除确认弹窗（HyperOS 风格）：有记录的日期 → 详情 → 修改 → 删除
  await page.locator('.calendar-day.has-record').first().click()
  await page.waitForTimeout(700)
  await page.getByRole('button', { name: '修改' }).click()
  await page.waitForTimeout(600)
  await page.getByRole('button', { name: '删除' }).click()
  await page.waitForTimeout(600)
  await page.screenshot({ path: `${OUT}/${theme}-dialog.png` })
  await page.keyboard.press('Escape')
  await page.waitForTimeout(300)
  await page.keyboard.press('Escape')
  await page.waitForTimeout(400)

  // 记一笔抽屉（模块 6 材质）
  await page.click('nav button:nth-of-type(2)')
  await page.waitForTimeout(800)
  await page.getByRole('button', { name: '记一笔' }).click()
  await page.waitForTimeout(700)
  await page.screenshot({ path: `${OUT}/${theme}-sheet.png` })
  await page.close()
}
await browser.close()
console.log('saved')
