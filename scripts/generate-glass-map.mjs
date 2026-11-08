/**
 * 生成 Liquid Glass 折射位移贴图 public/glass-refraction-map.png
 *
 * 依据（kube.io《Liquid Glass in the Browser》/ LogRocket 教程）：
 * - 折射发生在玻璃 bezel 区域：中心中性（128,128），沿边缘方向渐变位移
 * - 位移方向垂直于边界（Snell 定律：凸形剖面保持光线向内）
 * - R 通道 = X 位移，G 通道 = Y 位移，128 为中性（feDisplacementMap 的规范）
 * 贴图为 2x（560×136），CSS 元素约 280×68，由 feImage 缩放映射。
 * 用法：node scripts/generate-glass-map.mjs
 */
import sharp from 'sharp'

const W = 560
const H = 136
const BEZEL = 26 // 2x 下的 bezel 宽度（≈13 css px）

// 胶囊形 SDF（中心为零坐标）——近似导航的圆角长胶囊
function sdf(x, y) {
  const cx = W / 2
  const cy = H / 2
  const rx = W / 2 - BEZEL
  const ry = H / 2 - BEZEL
  const qx = Math.abs(x - cx) - rx
  const qy = Math.abs(y - cy) - ry
  const outside = Math.hypot(Math.max(qx, 0), Math.max(qy, 0))
  const inside = Math.min(Math.max(qx, qy), 0)
  return outside + inside - 0 // 0 处为外形边缘，内部为负
}

const raw = Buffer.alloc(W * H * 4)
for (let y = 0; y < H; y += 1) {
  for (let x = 0; x < W; x += 1) {
    const i = (y * W + x) * 4
    const d = sdf(x, y)
    const inner = -d // 距边缘的内向距离
    let r = 128
    let g = 128
    if (inner > 0 && inner < BEZEL) {
      // 凸形（squircle 近似）剖面：越靠边位移越强
      const t = 1 - inner / BEZEL
      const magnitude = Math.pow(t, 1.6)
      // 法线 = SDF 梯度的负方向（指向边界外），位移把内容"推向"边界 → 边缘弯曲
      const dx = sdf(x + 1, y) - sdf(x - 1, y)
      const dy = sdf(x, y + 1) - sdf(x, y - 1)
      const len = Math.hypot(dx, dy) || 1
      const nx = -dx / len
      const ny = -dy / len
      r = Math.max(1, Math.min(255, Math.round(128 + nx * magnitude * 127)))
      g = Math.max(1, Math.min(255, Math.round(128 + ny * magnitude * 127)))
    }
    raw[i] = r
    raw[i + 1] = g
    raw[i + 2] = 128 // B 未使用
    raw[i + 3] = 255
  }
}

await sharp(raw, { raw: { width: W, height: H, channels: 4 } })
  .png()
  .toFile('public/glass-refraction-map.png')
console.log('written public/glass-refraction-map.png')

/* ---------- 第二张：选中透镜的"放大镜"位移贴图（显示尺寸约 88×65） ----------
   Precision Lens（kube.io magnifying glass）：
   - 内部：放大镜位移 —— 位移指向中心、幅度随距中心距离增加（内容向中心收拢 → 视觉放大）
   - 边缘 bezel：叠加沿法线的凸形折射（外侧收边）
   - 两张 map 思路对应 kube.io "one for refraction on the sides, one for zooming" */
const LW = 176 // 2x of 88
const LH = 130 // 2x of 65
const LBEZEL = 18

function lensSdf(x, y) {
  const cx = LW / 2
  const cy = LH / 2
  const rx = LW / 2 - LBEZEL
  const ry = LH / 2 - LBEZEL
  const qx = Math.abs(x - cx) - rx
  const qy = Math.abs(y - cy) - ry
  const outside = Math.hypot(Math.max(qx, 0), Math.max(qy, 0))
  const inside = Math.min(Math.max(qx, qy), 0)
  return outside + inside
}

const lensRaw = Buffer.alloc(LW * LH * 4)
for (let y = 0; y < LH; y += 1) {
  for (let x = 0; x < LW; x += 1) {
    const i = (y * LW + x) * 4
    const d = lensSdf(x, y)
    const inner = -d
    let r = 128
    let g = 128
    if (inner > 0) {
      const cx = LW / 2
      const cy = LH / 2
      let dx = 0
      let dy = 0
      let mag = 0
      if (inner < LBEZEL) {
        // 边缘：凸形折射（同导航贴图，厚度加强）
        const t = 1 - inner / LBEZEL
        mag = Math.pow(t, 1.6) * 0.65
        const gx = lensSdf(x + 1, y) - lensSdf(x - 1, y)
        const gy = lensSdf(x, y + 1) - lensSdf(x, y - 1)
        const len = Math.hypot(gx, gy) || 1
        dx = -gx / len
        dy = -gy / len
        // 与中心放大位移合并（靠内部分）
        const pdx = cx - x
        const pdy = cy - y
        const plen = Math.hypot(pdx, pdy) || 1
        const innerMag = (inner / LW) * 1.6 * (1 - t) * 0.9
        dx = dx * mag + (pdx / plen) * innerMag
        dy = dy * mag + (pdy / plen) * innerMag
      } else {
        // 中心区域：纯放大镜位移（指向中心，随距离线性增强）
        const pdx = x - cx
        const pdy = y - cy
        const plen = Math.hypot(pdx, pdy) || 1
        const mag = Math.min(1, (plen / (LW / 2)) * 1.4)
        const n = plen > 0 ? 1 : 0
        dx = n ? (-pdx / plen) * mag : 0
        dy = n ? (-pdy / plen) * mag : 0
      }
      r = Math.max(1, Math.min(255, Math.round(128 + dx * 127)))
      g = Math.max(1, Math.min(255, Math.round(128 + dy * 127)))
    }
    lensRaw[i] = r
    lensRaw[i + 1] = g
    lensRaw[i + 2] = 128
    lensRaw[i + 3] = 255
  }
}

await sharp(lensRaw, { raw: { width: LW, height: LH, channels: 4 } })
  .png()
  .toFile('public/glass-lens-map.png')
console.log('written public/glass-lens-map.png')
