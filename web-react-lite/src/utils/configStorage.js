/**
 * 配置存储工具
 * 使用 localStorage 保存用户输入的 App ID 和 App Certificate
 */

const STORAGE_KEY = 'agora_config'

/**
 * 保存配置到 localStorage
 * @param {string} appId - Agora App ID
 * @param {string} appCertificate - Agora App Certificate
 * @param {string} channelName - 频道名称
 */
export function saveConfig(appId, appCertificate, channelName) {
  try {
    const config = {
      appId: appId.trim(),
      appCertificate: appCertificate.trim(),
      channelName: channelName.trim(),
      timestamp: Date.now()
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(config))
    return true
  } catch (error) {
    console.error('保存配置失败:', error)
    return false
  }
}

/**
 * 从 localStorage 读取配置
 * @returns {Object|null} 返回配置对象，如果不存在则返回 null
 */
export function loadConfig() {
  try {
    const configStr = localStorage.getItem(STORAGE_KEY)
    if (!configStr) {
      return null
    }
    const config = JSON.parse(configStr)
    return {
      appId: config.appId || '',
      appCertificate: config.appCertificate || '',
      channelName: config.channelName || ''
    }
  } catch (error) {
    console.error('读取配置失败:', error)
    return null
  }
}

