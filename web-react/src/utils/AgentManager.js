import { env } from '../config/env'

/**
 * Agent 管理器
 * 用于启动和停止 Conversational AI Agent
 * 类似于 VoiceAgent: src/services/agent.ts
 */
class AgentManager {
  // 使用本地 API 路径（类似于 Next.js API Routes）
  // 开发环境：通过 Vite 代理到 Express 服务器或直接代理到 Agora API
  // 生产环境：需要配置反向代理或使用 Express 服务器
  static get API_BASE_URL() {
    // 始终使用相对路径，由 Vite 代理或生产环境反向代理处理
    return '/api'
  }

  // 注意：认证信息现在由后端服务器处理，前端不需要生成认证头
  // 类似于 VoiceAgent，认证在 Next.js API Route 中处理

  /**
   * 启动 Agent
   * 对应 VoiceAgent: src/services/agent.ts startAgent()
   * @param {Object} parameter - Agent 启动参数
   * @param {string} parameter.name - 频道名称
   * @param {string} parameter.pipeline_id - Pipeline ID
   * @param {Object} parameter.properties - Agent 属性
   * @returns {Promise<string>} 返回 agentId
   */
  static async startAgent(parameter) {
    // 使用本地 API 服务器（类似于 Next.js /api/agent）
    const url = `${this.API_BASE_URL}/agent`

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(parameter)
      })

      if (!response.ok) {
        const errorText = await response.text()
        throw new Error(`HTTP ${response.status}: ${errorText}`)
      }

      const result = await response.json()

      if (result?.agent_id && result.agent_id.trim() !== '') {
        return result.agent_id
      } else {
        throw new Error(`Failed to parse agent_id from response: ${JSON.stringify(result)}`)
      }
    } catch (error) {
      console.error('Start Agent error:', error)
      throw error
    }
  }

  /**
   * 停止 Agent
   * 对应 VoiceAgent: src/services/agent.ts stopAgent()
   * @param {string} agentId - Agent ID
   * @returns {Promise<void>}
   */
  static async stopAgent(agentId) {
    if (!agentId) {
      console.warn('Agent ID is empty, skip stop agent')
      return
    }

    // 使用本地 API 路径，匹配 server.js 的路由
    // 路径格式：/api/agent/stop
    const url = `${this.API_BASE_URL}/agent/stop`

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ agentId })
      })

      if (!response.ok) {
        const errorText = await response.text()
        throw new Error(`HTTP ${response.status}: ${errorText}`)
      }

      console.log('Agent stopped successfully')
    } catch (error) {
      console.error('Stop Agent error:', error)
      throw error
    }
  }
}

export default AgentManager

