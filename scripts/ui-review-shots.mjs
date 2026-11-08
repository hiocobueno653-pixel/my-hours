/**
 * UI 审查截图采集：360px 手机视口，注入演示数据后遍历次级界面并保存整页截图。
 * 每个界面独立从首页进入（层间用整页重载复位），互不干扰。
 * 用法：node scripts/ui-review-shots.mjs [outDir]（默认 ui-shots）
 */
import { chromium } from 'playwright-core'
import { mkdirSync } from 'node:fs'

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
const BASE = process.env.MY_HOURS_BASE ?? 'http://localhost:4173/'
const OUT = process.argv[2] ?? 'ui-shots'
mkdirSync(OUT, { recursive: true })

const seed = () => {
  const recs = []
  for (let d = 1; d <= 24; d += 1) {
    const date = `2026-10-${String(d).padStart(2, '0')}`
    const wd = new Date(`${date}T00:00:00`).getDay()
    if (wd === 0) continue
    if (wd === 6 && d % 2 === 0) continue
    recs.push({
      date,
      hours: d === 21 ? 4 : 7.5 + (d % 3) * 0.5,
      remark: d % 5 === 0 ? '加班到九点' : '',
      rate: 25,
      settled: d <= 15,
    })
  }
  const entries = recs
    .filter((r) => r.settled)
    .map((r) => ({
      id: `wage-${r.date}`,
      date: r.date,
      type: 'income',
      amount: Math.round(r.hours * 25 * 100) / 100,
      category: '工资',
      remark: '结算工资',
      workDate: r.date,
    }))
  entries.push(
    { id: 'e1', date: '2026-10-24', type: 'expense', amount: 18.5, category: '餐饮', remark: '午饭' },
    { id: 'e2', date: '2026-10-23', type: 'expense', amount: 42, category: '交通', remark: '' },
    { id: 'e3', date: '2026-10-20', type: 'expense', amount: 120, category: '购物', remark: '鞋子' },
    { id: 'e4', date: '2026-10-18', type: 'income', amount: 200, category: '其他', remark: '闲鱼出二手' },
  )
  localStorage.setItem('my-hours.data.v1', JSON.stringify({ __v: 1, data: recs }))
  localStorage.setItem('my-hours.ledger.v1', JSON.stringify({ __v: 1, data: entries }))
  localStorage.setItem(
    'my-hours.workProfiles.v1',
    JSON.stringify({
      __v: 1,
      data: [
        { id: 'work-default', name: '默认工作', hourlyRate: 25 },
        { id: 'work-b', name: '周末家教', hourlyRate: 80 },
      ],
    }),
  )
  localStorage.setItem(
    'my-hours.budget.v1',
    JSON.stringify({ __v: 1, data: { monthlyExpenseBudget: 2000, monthlyIncomeGoal: 6000 } }),
  )
}

const wait = (page, ms = 1000) => page.waitForTimeout(ms)

async function fresh(page, _theme) {
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await wait(page, 1100)
}

async function shot(page, name, theme, selector, prepare) {
  try {
    if (prepare) await prepare()
    if (selector) await page.locator(selector).first().click({ timeout: 8000 })
    await wait(page)
    await page.screenshot({ path: `${OUT}/${theme}-${name}.png`, fullPage: true })
    console.log(`ok ${theme}-${name}`)
  } catch (error) {
    console.log(`skip ${theme}-${name}: ${error.message.split('\n')[0]}`)
  }
}

async function main() {
  const browser = await chromium.launch({ executablePath: CHROME, headless: true })
  for (const theme of ['light', 'dark']) {
    const page = await browser.newPage({ viewport: { width: 360, height: 740 } })
    await page.addInitScript((mode) => {
      localStorage.setItem('my-hours.theme', mode)
    }, theme)
    await page.addInitScript(seed)
    await fresh(page, theme)

    const goMine = async () => page.click('nav button:nth-of-type(3)')
    const goWork = async () => page.click('nav button:nth-of-type(1)')

    await shot(page, 'mine', theme, null, goMine)
    await fresh(page, theme)
    await shot(page, 'work-manager', theme, null, async () => {
      await goMine()
      await wait(page)
      await page.getByRole('button', { name: /工作管理|管理工作/ }).first().click({ timeout: 8000 })
    })
    await fresh(page, theme)
    await shot(page, 'backup', theme, null, async () => {
      await goMine()
      await wait(page)
      await page.getByRole('button', { name: /备份/ }).first().click({ timeout: 8000 })
    })
    await fresh(page, theme)
    await shot(page, 'month-detail', theme, null, async () => {
      await goWork()
      await wait(page)
      await page.locator('.month-detail-button').click({ timeout: 8000 })
    })
    await fresh(page, theme)
    await shot(page, 'day-detail', theme, '.calendar-day.has-record', goWork)
    await page.close()
  }
  await browser.close()
  console.log(`saved to ${OUT}/`)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
