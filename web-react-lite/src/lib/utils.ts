// 简化版 utils，用于 ConvoAI API

/**
 * 生成追踪 ID
 */
export function genTranceID(): string {
  return `${Date.now()}-${Math.random().toString(36).substring(2, 9)}`
}

/**
 * 解码流消息（简化版）
 */
export function decodeStreamMessage(data: Uint8Array | string): any {
  if (typeof data === 'string') {
    try {
      return JSON.parse(data)
    } catch {
      return data
    }
  }
  
  try {
    const decoder = new TextDecoder()
    const text = decoder.decode(data)
    return JSON.parse(text)
  } catch {
    return data
  }
}

