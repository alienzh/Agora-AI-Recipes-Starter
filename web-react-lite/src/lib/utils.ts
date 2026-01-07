// Simplified utils for ConvoAI API

/**
 * Generate trace ID
 */
export function genTranceID(): string {
  return `${Date.now()}-${Math.random().toString(36).substring(2, 9)}`
}

/**
 * Decode stream message (simplified version)
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

