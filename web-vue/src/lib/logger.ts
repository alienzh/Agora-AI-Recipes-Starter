// 简化版 logger，用于 ConvoAI API
export enum ELoggerType {
  log = 'log',
  info = 'info',
  debug = 'debug',
  error = 'error',
  warn = 'warn'
}

class LogManager {
  info(...args: unknown[]) {
    if (process.env.NODE_ENV === 'development') {
      console.info(...args)
    }
  }

  log(...args: unknown[]) {
    if (process.env.NODE_ENV === 'development') {
      console.log(...args)
    }
  }

  debug(...args: unknown[]) {
    if (process.env.NODE_ENV === 'development') {
      console.debug(...args)
    }
  }

  error(...args: unknown[]) {
    console.error(...args)
  }

  warn(...args: unknown[]) {
    console.warn(...args)
  }
}

export const logger = new LogManager()

