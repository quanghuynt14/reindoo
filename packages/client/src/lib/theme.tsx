import { createContext, useContext, useEffect, useMemo, useState } from 'react'

type Theme = 'dark' | 'light' | 'system'

type ThemeProviderProps = {
  children: React.ReactNode
  defaultTheme?: Theme
  storageKey?: string
}

type ThemeProviderState = {
  theme: Theme
  resolvedTheme: 'dark' | 'light'
  setTheme: (theme: Theme) => void
}

const initialState: ThemeProviderState = {
  theme: 'dark',
  resolvedTheme: 'dark',
  setTheme: () => null,
}

const ThemeProviderContext = createContext<ThemeProviderState>(initialState)

export function ThemeProvider({
  children,
  defaultTheme = 'dark',
  storageKey = 'dictionary-theme',
  ...props
}: ThemeProviderProps) {
  const [theme, setTheme] = useState<Theme>(
    () => (typeof window !== 'undefined' ? (localStorage.getItem(storageKey) as Theme) : null) || defaultTheme
  )
  const [resolvedTheme, setResolvedTheme] = useState<'dark' | 'light'>(defaultTheme === 'system' ? 'dark' : defaultTheme)

  const mediaQuery = useMemo(() => (typeof window !== 'undefined' ? window.matchMedia('(prefers-color-scheme: dark)') : null), [])

  // Helper to get resolved theme (dark|light) from current selection
  const getResolvedTheme = (sel: Theme): 'dark' | 'light' => {
    if (sel === 'system') {
      const prefersDark = mediaQuery?.matches ?? true
      return prefersDark ? 'dark' : 'light'
    }
    return sel
  }

  useEffect(() => {
    const root = window.document.documentElement
    const resolved = getResolvedTheme(theme)
    const current = root.classList.contains('dark') ? 'dark' : root.classList.contains('light') ? 'light' : null
    if (current !== resolved) {
      root.classList.remove('light', 'dark')
      root.classList.add(resolved)
    }
    setResolvedTheme(resolved)
    // Persist the actual theme choice (including 'system') to cookie for SSR rendering
    document.cookie = `${encodeURIComponent(storageKey)}=${encodeURIComponent(theme)}; Path=/; Max-Age=31536000; SameSite=Lax`
  }, [theme])

  // Keep cookie and class in sync when system preference changes
  useEffect(() => {
    if (!mediaQuery) return
    if (theme !== 'system') return
    const handler = () => {
      const resolved = getResolvedTheme('system')
      const root = document.documentElement
      const current = root.classList.contains('dark') ? 'dark' : root.classList.contains('light') ? 'light' : null
      if (current !== resolved) {
        root.classList.remove('light', 'dark')
        root.classList.add(resolved)
      }
      setResolvedTheme(resolved)
    }
    handler()
    mediaQuery.addEventListener?.('change', handler)
    return () => mediaQuery.removeEventListener?.('change', handler)
  }, [theme, mediaQuery, storageKey])

  const value = {
    theme,
    resolvedTheme,
    setTheme: (newTheme: Theme) => {
      if (typeof window !== 'undefined') {
        localStorage.setItem(storageKey, newTheme)
      }
      setTheme(newTheme)
    },
  }

  return (
    <ThemeProviderContext.Provider {...props} value={value}>
      {children}
    </ThemeProviderContext.Provider>
  )
}

export const useTheme = () => {
  const context = useContext(ThemeProviderContext)

  if (context === undefined)
    throw new Error('useTheme must be used within a ThemeProvider')

  return context
}
