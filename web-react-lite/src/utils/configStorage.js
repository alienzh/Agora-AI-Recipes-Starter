/**
 * Configuration storage utility
 * Use localStorage to save user-entered App ID and App Certificate
 */

const STORAGE_KEY = 'agora_config'

/**
 * Save configuration to localStorage
 * @param {string} appId - Agora App ID
 * @param {string} appCertificate - Agora App Certificate
 * @param {string} channelName - Channel name
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
    console.error('Failed to save configuration:', error)
    return false
  }
}

/**
 * Load configuration from localStorage
 * @returns {Object|null} Returns configuration object, or null if not exists
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
    console.error('Failed to load configuration:', error)
    return null
  }
}

