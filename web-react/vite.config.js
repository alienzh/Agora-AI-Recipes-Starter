import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'
import { loadEnv } from 'vite'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  // 加载环境变量
  const env = loadEnv(mode, process.cwd(), 'VITE_')
  const appId = env.VITE_AG_APP_ID || ''
  const authKey = env.VITE_AG_BASIC_AUTH_KEY || ''
  const authSecret = env.VITE_AG_BASIC_AUTH_SECRET || ''
  
  // 生成 Basic Auth 认证头
  const getAuthHeader = () => {
    if (authKey && authSecret) {
      const authString = `${authKey}:${authSecret}`
      const base64Auth = Buffer.from(authString).toString('base64')
      return `Basic ${base64Auth}`
    }
    return ''
  }
  
  return {
    plugins: [react()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src')
      }
    },
    server: {
      proxy: {
        // 代理到本地 Express 服务器（更可靠）
        // 类似于 Next.js API Routes，但使用独立的 Express 服务器
        // 前端调用 /api/*，Vite 自动代理到 Express 服务器 (localhost:3001)
        '/api': {
          target: 'http://localhost:3001',
          changeOrigin: true,
          // 不重写路径，直接透传
          configure: (proxy, _options) => {
            proxy.on('error', (err, req, res) => {
              console.error('[Vite Proxy] Proxy error:', err)
              console.warn('[Vite Proxy] 提示: 请确保 Express 服务器已启动 (npm run dev:server)')
            })
          }
        }
      }
    }
  }
})

