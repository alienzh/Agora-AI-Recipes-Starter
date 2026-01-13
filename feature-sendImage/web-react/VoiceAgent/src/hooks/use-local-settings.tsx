import * as React from 'react'

export function useLocalSettings<T>(key: string) {
  const [settings, setSettings] = React.useState<T | null>(null)

  React.useEffect(() => {
    const settings = localStorage.getItem(key)
    if (settings) {
      setSettings(JSON.parse(settings))
    }
  }, [key])

  React.useEffect(() => {
    localStorage.setItem(key, JSON.stringify(settings))
  }, [key, settings])

  return [settings, setSettings] as const
}
