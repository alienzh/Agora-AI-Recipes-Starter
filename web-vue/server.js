/**
 * Express Server for Agora Agent API Proxy
 * 类似于 Next.js API Routes，用于代理 Agora API 请求，解决 CORS 问题
 */
import express from 'express'
import cors from 'cors'
import dotenv from 'dotenv'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// 加载环境变量
dotenv.config({ path: path.resolve(__dirname, '.env.local') })

const app = express()
const PORT = process.env.PORT || 3001

// 中间件
app.use(cors()) // 允许跨域
app.use(express.json()) // 解析 JSON 请求体

// 从环境变量读取配置
const AG_APP_ID = process.env.VITE_AG_APP_ID || ''
const AG_BASIC_AUTH_KEY = process.env.VITE_AG_BASIC_AUTH_KEY || ''
const AG_BASIC_AUTH_SECRET = process.env.VITE_AG_BASIC_AUTH_SECRET || ''

// Agora API 基础 URL
const AGORA_API_BASE = 'https://api.agora.io'

/**
 * 生成 Basic Auth 认证头
 */
function generateAuthHeader() {
  if (!AG_BASIC_AUTH_KEY || !AG_BASIC_AUTH_SECRET) {
    throw new Error('VITE_AG_BASIC_AUTH_KEY 和 VITE_AG_BASIC_AUTH_SECRET 未配置')
  }
  const authString = `${AG_BASIC_AUTH_KEY}:${AG_BASIC_AUTH_SECRET}`
  const base64Auth = Buffer.from(authString).toString('base64')
  return `Basic ${base64Auth}`
}

/**
 * 启动 Agent
 * POST /api/agent
 * 对应 VoiceAgent: src/app/api/agent/route.ts
 */
app.post('/api/agent', async (req, res) => {
  try {
    if (!AG_APP_ID) {
      return res.status(500).json({ 
        error: 'VITE_AG_APP_ID 未配置' 
      })
    }

    const { name, pipeline_id, properties } = req.body

    if (!name || !pipeline_id || !properties) {
      return res.status(400).json({ 
        error: '缺少必要参数: name, pipeline_id, properties' 
      })
    }

    // 构建 Agora API 请求 URL
    // 注意：这里使用的是 v2 API，VoiceAgent 使用的是 v5 API
    const url = `${AGORA_API_BASE}/cn/api/conversational-ai-agent/v2/projects/${AG_APP_ID}/join/`

    // 构建请求体（直接透传，类似 VoiceAgent 的透明代理模式）
    const requestBody = {
      name,
      pipeline_id,
      properties
    }

    console.log('[Server] Proxying request to:', url)
    console.log('[Server] Request body:', JSON.stringify(requestBody, null, 2))

    // 发送请求到 Agora API
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': generateAuthHeader()
      },
      body: JSON.stringify(requestBody)
    })

    const responseData = await response.json()
    console.log('[Server] Response status:', response.status)
    console.log('[Server] Response data:', JSON.stringify(responseData, null, 2))

    // 返回响应（透传状态码和数据）
    return res.status(response.status).json(responseData)
  } catch (error) {
    console.error('[Server] Error:', error)
    return res.status(500).json({ 
      error: 'Internal Server Error',
      message: error.message 
    })
  }
})

/**
 * 停止 Agent
 * POST /api/agent/stop
 */
app.post('/api/agent/stop', async (req, res) => {
  try {
    if (!AG_APP_ID) {
      return res.status(500).json({ 
        error: 'VITE_AG_APP_ID 未配置' 
      })
    }

    const { agentId } = req.body

    if (!agentId) {
      return res.status(400).json({ 
        error: '缺少必要参数: agentId' 
      })
    }

    const url = `${AGORA_API_BASE}/cn/api/conversational-ai-agent/v2/projects/${AG_APP_ID}/agents/${agentId}/leave`

    console.log('[Server] Stopping agent:', agentId)

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': generateAuthHeader()
      },
      body: JSON.stringify({})
    })

    if (!response.ok) {
      const errorText = await response.text()
      return res.status(response.status).json({ 
        error: errorText 
      })
    }

    return res.status(200).json({ success: true })
  } catch (error) {
    console.error('[Server] Error:', error)
    return res.status(500).json({ 
      error: 'Internal Server Error',
      message: error.message 
    })
  }
})

/**
 * 健康检查
 * GET /api/health
 */
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok',
    message: 'Agora Agent API Proxy Server is running',
    config: {
      hasAppId: !!AG_APP_ID,
      hasAuthKey: !!AG_BASIC_AUTH_KEY,
      hasAuthSecret: !!AG_BASIC_AUTH_SECRET
    }
  })
})

// 启动服务器
app.listen(PORT, () => {
  console.log(`\n🚀 Agora Agent API Proxy Server running on http://localhost:${PORT}`)
  console.log(`📝 Health check: http://localhost:${PORT}/api/health`)
  console.log(`🔗 API endpoints:`)
  console.log(`   POST /api/agent - Start an agent`)
  console.log(`   POST /api/agent/stop - Stop an agent`)
  console.log(`\n⚠️  请确保已配置以下环境变量:`)
  console.log(`   - VITE_AG_APP_ID`)
  console.log(`   - VITE_AG_BASIC_AUTH_KEY`)
  console.log(`   - VITE_AG_BASIC_AUTH_SECRET`)
  console.log(`\n`)
})

