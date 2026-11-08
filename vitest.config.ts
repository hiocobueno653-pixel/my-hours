import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    // 组件级集成测试（jsdom 渲染 + userEvent）在负载下可超过默认 5s，
    // 15s 阈值避免把慢机器上的抖动误判为失败
    testTimeout: 15000,
    hookTimeout: 15000,
    // 限制并行 worker：本机 IO 较慢，过多 worker 争抢会让
    // 高负载下的 userEvent 打字流丢字符（组件测试偶发失败）
    pool: 'forks',
    maxWorkers: 2,
  },
})
