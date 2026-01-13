import { env } from '../config/env'

/**
 * 生成 Token
 * @param {string} channelName - 频道名称
 * @param {string} uid - 用户ID
 * @param {number} expire - 过期时间（秒），默认 86400（24小时）
 * @param {number[]} types - Token 类型数组
 * @returns {Promise<string|null>} 返回 token 或 null
 */
export async function generateToken(channelName, uid, expire = 86400, types = [1]) {
  // 检查配置是否已填写
  if (!env.AG_APP_ID || !env.AG_APP_CERTIFICATE) {
    throw new Error('请先在 .env.local 文件中配置 VITE_AG_APP_ID 和 VITE_AG_APP_CERTIFICATE')
  }
  
  const params = {
    appCertificate: env.AG_APP_CERTIFICATE,
    appId: env.AG_APP_ID,
    channelName: channelName,
    expire: expire,
    src: 'Web',
    ts: 0,
    types: types,
    uid: uid,
  }

  const url = 'https://service.apprtc.cn/toolbox/v2/token/generate'

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(params),
    })

    // 检查 HTTP 状态
    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`HTTP ${response.status}: ${errorText}`)
    }

    const result = await response.json()

    // 提取 token（支持多种响应格式）
    let token = null
    
    if (result?.data?.token) {
      token = result.data.token
    } else if (result?.token) {
      token = result.token
    } else if (result?.data && typeof result.data === 'string') {
      token = result.data
    } else if (result?.result?.token) {
      token = result.result.token
    } else if (result?.response?.data?.token) {
      token = result.response.data.token
    } else if (Array.isArray(result) && result.length > 0) {
      if (typeof result[0] === 'string') {
        token = result[0]
      } else if (result[0]?.token) {
        token = result[0].token
      }
    }

    if (token) {
      return token
    }

    throw new Error('无法从响应中提取 token')
  } catch (error) {
    console.error('Token generation error:', error)
    throw error
  }
}

