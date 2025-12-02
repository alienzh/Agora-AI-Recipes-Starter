/**
 * 环境变量配置
 * 从 .env 文件中读取配置
 */
export const env = {
  AG_APP_ID: import.meta.env.VITE_AG_APP_ID || '',
  AG_APP_CERTIFICATE: import.meta.env.VITE_AG_APP_CERTIFICATE || '',
  AG_BASIC_AUTH_KEY: import.meta.env.VITE_AG_BASIC_AUTH_KEY || '',
  AG_BASIC_AUTH_SECRET: import.meta.env.VITE_AG_BASIC_AUTH_SECRET || '',
  AG_PIPELINE_ID: import.meta.env.VITE_AG_PIPELINE_ID || '',
}

/**
 * 验证必需的环境变量是否已配置
 */
export function validateEnv() {
  const required = [
    'AG_APP_ID',
    'AG_APP_CERTIFICATE',
    'AG_BASIC_AUTH_KEY',
    'AG_BASIC_AUTH_SECRET',
    'AG_PIPELINE_ID',
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

