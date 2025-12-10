/**
 * 生成 Token
 * @param {string} channelName - 频道名称
 * @param {string} uid - 用户ID
 * @param {number} expire - 过期时间（秒），默认 86400（24小时）
 * @param {number[]} types - Token 类型数组
 * @param {string} appId - Agora App ID
 * @param {string} appCertificate - Agora App Certificate（选填，为空时返回 null 表示不使用 token）
 * @returns {Promise<string|null>} 返回 token（如果 appCertificate 为空则返回 null）
 */
export async function generateToken(channelName, uid, expire = 86400, types = [1], appId, appCertificate) {
  // 检查配置是否已填写
  if (!appId) {
    throw new Error('App ID 未配置')
  }
  
  // 如果 appCertificate 为空，返回 null 表示不使用 token
  if (!appCertificate || appCertificate.trim() === '') {
    return null
  }
  
  const params = {
    appCertificate: appCertificate,
    appId: appId,
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

