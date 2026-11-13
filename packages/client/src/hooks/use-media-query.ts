import { useCallback, useMemo, useSyncExternalStore } from 'react'

export function useMediaQuery(query: string, defaultValue = false): boolean {
  const mediaQueryList = useMemo(() => {
    if (
      typeof window === 'undefined' ||
      typeof window.matchMedia === 'undefined'
    ) {
      return null
    }
    return window.matchMedia(query)
  }, [query])

  const subscribe = useCallback(
    (callback: () => void) => {
      if (!mediaQueryList) return () => {}

      // Modern API with legacy fallback (Safari <14)
      if (mediaQueryList.addEventListener) {
        mediaQueryList.addEventListener('change', callback)
        return () => mediaQueryList.removeEventListener('change', callback)
      }

      mediaQueryList.addListener(callback)
      return () => mediaQueryList.removeListener(callback)
    },
    [mediaQueryList]
  )

  const getSnapshot = useCallback(
    () => mediaQueryList?.matches ?? defaultValue,
    [mediaQueryList, defaultValue]
  )

  const getServerSnapshot = useCallback(() => defaultValue, [defaultValue])

  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot)
}
