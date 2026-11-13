import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { LANGUAGE  } from '@practice/shared'
import { Clock, Home, Keyboard, Languages, Search } from 'lucide-react'
import type {Language} from '@practice/shared';
import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
} from '@/components/ui/command'

type RecentSearch = {
  word: string
  sourceLanguage: Language
  targetLanguage: Language
  timestamp: number
}

const RECENT_SEARCHES_KEY = 'dictionary-recent-searches'
const MAX_RECENT_SEARCHES = 10

export function CommandPalette() {
  const [open, setOpen] = useState(false)
  const [recentSearches, setRecentSearches] = useState<Array<RecentSearch>>([])
  const navigate = useNavigate()

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        setOpen((open) => !open)
      }
    }

    document.addEventListener('keydown', down)
    return () => document.removeEventListener('keydown', down)
  }, [])

  useEffect(() => {
    if (open) {
      const stored = localStorage.getItem(RECENT_SEARCHES_KEY)
      if (stored) {
        try {
          setRecentSearches(JSON.parse(stored))
        } catch {
          setRecentSearches([])
        }
      }
    }
  }, [open])

  const handleNavigate = useCallback(
    (path: string, search?: Record<string, unknown>) => {
      setOpen(false)
      navigate({ to: path, search } as never)
    },
    [navigate]
  )

  const getLanguageLabel = (lang: Language) => {
    switch (lang) {
      case LANGUAGE.ENGLISH:
        return 'Tiếng Anh'
      case LANGUAGE.FRENCH:
        return 'Tiếng Pháp'
      case LANGUAGE.VIETNAMESE:
        return 'Tiếng Việt'
      case LANGUAGE.SPANISH:
        return 'Tiếng Tây Ban Nha'
      case LANGUAGE.GERMAN:
        return 'Tiếng Đức'
      default:
        return lang
    }
  }

  const languagePairs = [
    { source: LANGUAGE.FRENCH, target: LANGUAGE.VIETNAMESE, label: 'Pháp → Việt' },
    { source: LANGUAGE.FRENCH, target: LANGUAGE.ENGLISH, label: 'Pháp → Anh' },
    { source: LANGUAGE.ENGLISH, target: LANGUAGE.FRENCH, label: 'Anh → Pháp' },
    { source: LANGUAGE.ENGLISH, target: LANGUAGE.VIETNAMESE, label: 'Anh → Việt' },
    { source: LANGUAGE.VIETNAMESE, target: LANGUAGE.FRENCH, label: 'Việt → Pháp' },
    { source: LANGUAGE.VIETNAMESE, target: LANGUAGE.ENGLISH, label: 'Việt → Anh' },
    { source: LANGUAGE.SPANISH, target: LANGUAGE.ENGLISH, label: 'Tây Ban Nha → Anh' },
    { source: LANGUAGE.ENGLISH, target: LANGUAGE.SPANISH, label: 'Anh → Tây Ban Nha' },
    { source: LANGUAGE.GERMAN, target: LANGUAGE.ENGLISH, label: 'Đức → Anh' },
    { source: LANGUAGE.ENGLISH, target: LANGUAGE.GERMAN, label: 'Anh → Đức' },
  ]

  return (
    <>
      <CommandDialog open={open} onOpenChange={setOpen}>
        <CommandInput placeholder="Gõ để tìm nhanh..." />
        <CommandList>
          <CommandEmpty>Không có kết quả nào.</CommandEmpty>
          
          <CommandGroup heading="Điều hướng">
            <CommandItem
              onSelect={() => handleNavigate('/')}
            >
              <Home className="mr-2 h-4 w-4" />
              <span>Trang chủ</span>
            </CommandItem>
            <CommandItem
              onSelect={() => handleNavigate('/dictionary')}
            >
              <Languages className="mr-2 h-4 w-4" />
              <span>Đổi cặp ngôn ngữ</span>
            </CommandItem>
            <CommandItem
              onSelect={() => handleNavigate('/history')}
            >
              <Clock className="mr-2 h-4 w-4" />
              <span>Lịch sử</span>
            </CommandItem>
          </CommandGroup>

          <CommandSeparator />

          <CommandGroup heading="Chuyển nhanh cặp ngôn ngữ">
            {languagePairs.map((pair) => (
              <CommandItem
                key={`${pair.source}-${pair.target}`}
                onSelect={() =>
                  handleNavigate('/dictionary/search', {
                    sourceLanguage: pair.source,
                    targetLanguage: pair.target,
                  })
                }
              >
                <Search className="mr-2 h-4 w-4" />
                <span>{pair.label}</span>
              </CommandItem>
            ))}
          </CommandGroup>

          {recentSearches.length > 0 && (
            <>
              <CommandSeparator />
              <CommandGroup heading="Tra gần đây">
                {recentSearches.slice(0, 5).map((search, index) => (
                  <CommandItem
                    key={`${search.word}-${search.timestamp}-${index}`}
                    onSelect={() =>
                      handleNavigate('/dictionary/search', {
                        sourceLanguage: search.sourceLanguage,
                        targetLanguage: search.targetLanguage,
                      })
                    }
                  >
                    <Clock className="mr-2 h-4 w-4" />
                    <span>
                      "{search.word}" ({getLanguageLabel(search.sourceLanguage)} →{' '}
                      {getLanguageLabel(search.targetLanguage)})
                    </span>
                  </CommandItem>
                ))}
              </CommandGroup>
            </>
          )}

          <CommandSeparator />
          
          <CommandGroup heading="Mẹo">
            <CommandItem disabled>
              <Keyboard className="mr-2 h-4 w-4" />
              <span className="text-xs text-muted-foreground">
                Nhấn{' '}
                <kbd className="pointer-events-none inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground opacity-100">
                  <span className="text-xs">⌘</span>K
                </kbd>{' '}
                để mở bảng này bất cứ lúc nào
              </span>
            </CommandItem>
          </CommandGroup>
        </CommandList>
      </CommandDialog>
    </>
  )
}

export function addRecentSearch(word: string, sourceLanguage: Language, targetLanguage: Language) {
  const stored = localStorage.getItem(RECENT_SEARCHES_KEY)
  let searches: Array<RecentSearch> = []
  
  if (stored) {
    try {
      searches = JSON.parse(stored)
    } catch {
      searches = []
    }
  }

  // Remove duplicates and add new search at the beginning
  searches = searches.filter(
    (s) => !(s.word === word && s.sourceLanguage === sourceLanguage && s.targetLanguage === targetLanguage)
  )
  
  searches.unshift({
    word,
    sourceLanguage,
    targetLanguage,
    timestamp: Date.now(),
  })

  // Keep only the most recent searches
  searches = searches.slice(0, MAX_RECENT_SEARCHES)

  localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(searches))
}
