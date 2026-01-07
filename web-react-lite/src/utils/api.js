/**
 * Generate Token
 * @param {string} channelName - Channel name
 * @param {string} uid - User ID
 * @param {number} expire - Expiration time (seconds), default 86400 (24 hours)
 * @param {number[]} types - Token type array
 * @param {string} appId - Agora App ID
 * @param {string} appCertificate - Agora App Certificate (optional, returns null if empty to indicate no token used)
 * @returns {Promise<string|null>} Returns token (returns null if appCertificate is empty)
 */
export async function generateToken(channelName, uid, expire = 86400, types = [1], appId, appCertificate) {
  // Check if configuration is filled
  if (!appId) {
    throw new Error('App ID not configured')
  }
  
  // If appCertificate is empty, return null to indicate no token used
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

    // Check HTTP status
    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`HTTP ${response.status}: ${errorText}`)
    }

    const result = await response.json()

    // Extract token (supports multiple response formats)
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

    throw new Error('Unable to extract token from response')
  } catch (error) {
    console.error('Token generation error:', error)
    throw error
  }
}

