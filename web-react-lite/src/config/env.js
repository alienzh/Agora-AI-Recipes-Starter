/**
 * 环境变量配置
 * 从 .env 文件中读取配置
 * 
 * web-react-lite 版本只需要 RTM、RTC 和 ConvoAI 相关的配置
 * 不需要 Agent API 相关的配置（BASIC_AUTH_KEY、BASIC_AUTH_SECRET、PIPELINE_ID）
 */
export const env = {
  AG_APP_ID: import.meta.env.VITE_AG_APP_ID || '',
  AG_APP_CERTIFICATE: import.meta.env.VITE_AG_APP_CERTIFICATE || '',
}

/**
 * 验证必需的环境变量是否已配置
 */
export function validateEnv() {
  const required = [
    'AG_APP_ID',
    'AG_APP_CERTIFICATE',
  ]
  
  const missing = required.filter(key => !env[key])
  
  if (missing.length > 0) {
    console.warn('缺少以下环境变量:', missing.join(', '))
    console.warn('请复制 .env.example 为 .env 并填写相应的值')
    return false
  }
  
  return true
}

export default env

