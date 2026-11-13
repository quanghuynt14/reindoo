import { createFileRoute } from '@tanstack/react-router'
import { useInfiniteQuery } from '@tanstack/react-query'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  ArrowDownWideNarrow,
  ArrowUpWideNarrow,
  Filter,
  Loader2,
  RefreshCw,
  Shuffle,
} from 'lucide-react'
import { LANGUAGE } from '@practice/shared'
import type { DictionaryHistoryItem } from '@/types/history'
import { env } from '@/config/env'
import { Snowfall } from '@/components/Snowfall'
import { DictionaryReelCard } from '@/components/reels/DictionaryReelCard'
import { useMediaQuery } from '@/hooks/use-media-query'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'

export const Route = createFileRoute('/_authenticated/reels')({
  component: Reels,
})

// Constants for reels functionality
const ITEMS_BEFORE_FETCH = 3 // Trigger infinite scroll when this many items from end
const PULL_TO_REFRESH_THRESHOLD = 80 // Pixels to pull down before refresh triggers

type ReelItem = { type: 'dictionary'; data: DictionaryHistoryItem }

type ReelsResponse = {
  items: Array<ReelItem>
  nextPage: number | null
  hasMore: boolean
}

type ReelSort = 'newest' | 'oldest' | 'random'

const fetchReels = async ({
  pageParam = 1,
  sourceLanguage,
  targetLanguage,
  sort,
}: {
  pageParam?: number
  sourceLanguage?: string
  targetLanguage?: string
  sort?: ReelSort
}): Promise<ReelsResponse> => {
  const params = new URLSearchParams({
    page: pageParam.toString(),
    limit: '10',
  })

  if (sourceLanguage && sourceLanguage !== 'all') {
    params.append('sourceLanguage', sourceLanguage)
  }

  if (targetLanguage && targetLanguage !== 'all') {
    params.append('targetLanguage', targetLanguage)
  }

  if (sort) {
    params.append('sort', sort)
  }

  const response = await fetch(
    `${env.VITE_API_URL}/api/reels?${params.toString()}`,
    {
      method: 'GET',
      credentials: 'include',
    }
  )

  if (!response.ok) {
    throw new Error('Không tải được nội dung')
  }

  return response.json()
}

// Language options configuration
const LANGUAGE_OPTIONS = [
  { value: LANGUAGE.ENGLISH, label: 'Tiếng Anh' },
  { value: LANGUAGE.FRENCH, label: 'Tiếng Pháp' },
  { value: LANGUAGE.VIETNAMESE, label: 'Tiếng Việt' },
  { value: LANGUAGE.SPANISH, label: 'Tiếng Tây Ban Nha' },
  { value: LANGUAGE.GERMAN, label: 'Tiếng Đức' },
] as const

// ─── Shared background (Aurora + Snowfall) ──────────────────────────────────

function ReelsBackground() {
  return (
    <>
      <div className="aurora-background">
        <div className="aurora-layer"></div>
      </div>
      <Snowfall />
    </>
  )
}

// ─── Language Filter Component ──────────────────────────────────────────────

function LanguageFilterControls({
  showFilters,
  onToggleFilters,
  sourceLanguage,
  onSourceLanguageChange,
  targetLanguage,
  onTargetLanguageChange,
  sort,
  onCycleSort,
}: {
  showFilters: boolean
  onToggleFilters: () => void
  sourceLanguage: string
  onSourceLanguageChange: (value: string) => void
  targetLanguage: string
  onTargetLanguageChange: (value: string) => void
  sort: ReelSort
  onCycleSort: () => void
}) {
  const sortMeta =
    sort === 'newest'
      ? {
          label: 'Mới',
          title: 'Sắp xếp: mới nhất trước',
          icon: ArrowDownWideNarrow,
        }
      : sort === 'oldest'
        ? {
            label: 'Cũ',
            title: 'Sắp xếp: cũ nhất trước',
            icon: ArrowUpWideNarrow,
          }
        : {
            label: 'Ngẫu nhiên',
            title: 'Sắp xếp: thứ tự ngẫu nhiên',
            icon: Shuffle,
          }

  const SortIcon = sortMeta.icon

  return (
    <div className="fixed top-20 left-4 z-50 flex flex-col items-start gap-2">
      <div className="flex items-center gap-2">
        <button
          onClick={onCycleSort}
          aria-label={sortMeta.title}
          title={sortMeta.title}
          className="rounded-lg border border-border bg-background/90 p-2 shadow-lg backdrop-blur-sm"
        >
          <SortIcon className="h-5 w-5 text-primary" />
        </button>

        <button
          onClick={onToggleFilters}
          aria-label="Lọc theo ngôn ngữ"
          title="Lọc theo ngôn ngữ"
          className="rounded-lg border border-border bg-background/90 p-2 shadow-lg backdrop-blur-sm"
        >
          <Filter className="h-5 w-5 text-primary" />
        </button>
      </div>

      {showFilters && (
        <div className="flex w-[180px] flex-col gap-2 rounded-lg border border-border bg-background/90 p-2 shadow-lg backdrop-blur-sm">
          <Select value={sourceLanguage} onValueChange={onSourceLanguageChange}>
            <SelectTrigger className="w-full" size="sm">
              <SelectValue placeholder="Ngôn ngữ nguồn" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Mọi ngôn ngữ nguồn</SelectItem>
              {LANGUAGE_OPTIONS.map((lang) => (
                <SelectItem key={lang.value} value={lang.value}>
                  {lang.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>

          <Select value={targetLanguage} onValueChange={onTargetLanguageChange}>
            <SelectTrigger className="w-full" size="sm">
              <SelectValue placeholder="Ngôn ngữ đích" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Mọi ngôn ngữ đích</SelectItem>
              {LANGUAGE_OPTIONS.map((lang) => (
                <SelectItem key={lang.value} value={lang.value}>
                  {lang.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      )}
    </div>
  )
}

// ─── Pull-to-refresh hook ───────────────────────────────────────────────────

function usePullToRefresh(
  containerEl: HTMLDivElement | null,
  onRefresh: () => Promise<unknown>,
  disabled = false
) {
  const [isRefreshing, setIsRefreshing] = useState(false)
  const touchStartY = useRef(0)
  const pullDistance = useRef(0)
  const shouldRefresh = useRef(false)

  const handleTouchStart = useCallback(
    (e: React.TouchEvent) => {
      if (disabled) return
      if (containerEl?.scrollTop === 0) {
        touchStartY.current = e.touches[0].clientY
        shouldRefresh.current = false
      }
    },
    [containerEl, disabled]
  )

  const handleTouchMove = useCallback(
    (e: React.TouchEvent) => {
      if (disabled) return
      if (containerEl?.scrollTop === 0 && touchStartY.current > 0) {
        pullDistance.current = e.touches[0].clientY - touchStartY.current
        if (pullDistance.current > PULL_TO_REFRESH_THRESHOLD) {
          shouldRefresh.current = true
        }
      }
    },
    [containerEl, disabled]
  )

  const handleTouchEnd = useCallback(async () => {
    if (disabled) return
    if (
      shouldRefresh.current &&
      pullDistance.current > PULL_TO_REFRESH_THRESHOLD
    ) {
      setIsRefreshing(true)
      try {
        await onRefresh()
      } finally {
        setIsRefreshing(false)
      }
    }
    touchStartY.current = 0
    pullDistance.current = 0
    shouldRefresh.current = false
  }, [onRefresh, disabled])

  return { isRefreshing, handleTouchStart, handleTouchMove, handleTouchEnd }
}

// ─── Main component ─────────────────────────────────────────────────────────

function Reels() {
  const [currentIndex, setCurrentIndex] = useState(0)
  const [sourceLanguage, setSourceLanguage] = useState<string>('all')
  const [targetLanguage, setTargetLanguage] = useState<string>('all')
  const [sort, setSort] = useState<ReelSort>('random')
  const [showFilters, setShowFilters] = useState(false)
  const [containerEl, setContainerEl] = useState<HTMLDivElement | null>(null)
  const [isVeiled, setIsVeiled] = useState(true)
  const toggleVeil = useCallback(() => setIsVeiled((v) => !v), [])
  const [overlayOpen, setOverlayOpen] = useState(false)
  const isDesktop = useMediaQuery('(min-width: 768px)')
  const [perCardReveal, setPerCardReveal] = useState(
    () => localStorage.getItem('reels-per-card-reveal') === 'true'
  )

  const handleToggleRevealMode = useCallback(() => {
    setPerCardReveal((prev) => {
      const next = !prev
      localStorage.setItem('reels-per-card-reveal', String(next))
      return next
    })
    // Reset global veil when switching modes so nothing is left exposed
    setIsVeiled(true)
  }, [])

  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    isLoading,
    isError,
    refetch,
  } = useInfiniteQuery({
    queryKey: ['reels', sourceLanguage, targetLanguage, sort],
    queryFn: ({ pageParam }) =>
      fetchReels({ pageParam, sourceLanguage, targetLanguage, sort }),
    getNextPageParam: (lastPage) => lastPage.nextPage,
    initialPageParam: 1,
  })

  // Item 7: Memoize the flattened items list with page+item indices for stable keys
  const allItems = useMemo(
    () =>
      data?.pages.flatMap((page, pageIdx) =>
        page.items.map((item, itemIdx) => ({ ...item, pageIdx, itemIdx }))
      ) ?? [],
    [data]
  )

  // Ref for query-derived values so handleScroll stays stable and doesn't
  // cause the scroll listener to re-attach on every data change.
  const queryStateRef = useRef({
    itemCount: 0,
    hasNextPage: false,
    isFetchingNextPage: false,
  })
  queryStateRef.current = {
    itemCount: allItems.length,
    hasNextPage: hasNextPage ?? false,
    isFetchingNextPage,
  }

  // Effect A eliminated: filter reset is now handled inline in the change handlers below.
  const handleSourceLanguageChange = useCallback(
    (value: string) => {
      setSourceLanguage(value)
      setCurrentIndex(0)
      containerEl?.scrollTo({ top: 0 })
    },
    [containerEl]
  )

  const handleTargetLanguageChange = useCallback(
    (value: string) => {
      setTargetLanguage(value)
      setCurrentIndex(0)
      containerEl?.scrollTo({ top: 0 })
    },
    [containerEl]
  )

  const handleSortChange = useCallback(
    (value: ReelSort) => {
      setSort(value)
      setCurrentIndex(0)
      containerEl?.scrollTo({ top: 0 })
    },
    [containerEl]
  )

  const handleCycleSort = useCallback(() => {
    handleSortChange(
      sort === 'random' ? 'newest' : sort === 'newest' ? 'oldest' : 'random'
    )
  }, [handleSortChange, sort])

  // Effects B + C eliminated: scroll handler uses functional updater (no ref needed)
  // and triggers infinite scroll fetch directly.
  const handleScroll = useCallback(() => {
    if (!containerEl) return

    const scrollTop = containerEl.scrollTop
    const itemHeight = containerEl.clientHeight || window.innerHeight
    const newIndex = Math.round(scrollTop / itemHeight)

    // Functional updater avoids stale closure — no currentIndexRef needed
    setCurrentIndex((prev) => (newIndex !== prev ? newIndex : prev))

    // Infinite scroll: fetch next page when approaching the end
    const qs = queryStateRef.current
    if (
      newIndex >= qs.itemCount - ITEMS_BEFORE_FETCH &&
      qs.hasNextPage &&
      !qs.isFetchingNextPage
    ) {
      fetchNextPage()
    }
  }, [containerEl, fetchNextPage])

  // The only remaining useEffect: syncing with an external system (DOM scroll event).
  useEffect(() => {
    if (!containerEl) return

    containerEl.addEventListener('scroll', handleScroll)
    return () => containerEl.removeEventListener('scroll', handleScroll)
  }, [containerEl, handleScroll])

  // Item 8: Pull-to-refresh extracted to a custom hook with try/finally (Item 6)
  const handleRefresh = useCallback(async () => {
    await refetch()
    setCurrentIndex(0)
    containerEl?.scrollTo({ top: 0 })
  }, [refetch, containerEl])

  const { isRefreshing, handleTouchStart, handleTouchMove, handleTouchEnd } =
    usePullToRefresh(containerEl, handleRefresh, overlayOpen)

  if (isLoading) {
    return (
      <>
        <ReelsBackground />
        <div className="fixed inset-0 flex items-center justify-center bg-background">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
      </>
    )
  }

  if (isError) {
    return (
      <>
        <ReelsBackground />
        <div className="fixed inset-0 flex items-center justify-center bg-background">
          <div className="text-center space-y-4">
            <p className="text-destructive">Failed to load reels</p>
            <button
              onClick={() => refetch()}
              className="px-4 py-2 bg-primary text-primary-foreground rounded-lg"
            >
              Retry
            </button>
          </div>
        </div>
      </>
    )
  }

  if (allItems.length === 0) {
    return (
      <>
        <ReelsBackground />

        <LanguageFilterControls
          showFilters={showFilters}
          onToggleFilters={() => setShowFilters(!showFilters)}
          sourceLanguage={sourceLanguage}
          onSourceLanguageChange={handleSourceLanguageChange}
          targetLanguage={targetLanguage}
          onTargetLanguageChange={handleTargetLanguageChange}
          sort={sort}
          onCycleSort={handleCycleSort}
        />

        <div className="fixed inset-0 flex items-center justify-center bg-background">
          <div className="text-center space-y-4 p-8">
            <p className="text-muted-foreground text-lg">
              {sourceLanguage !== 'all' || targetLanguage !== 'all'
                ? 'Không có nội dung nào khớp với bộ lọc. Thử nới bộ lọc ngôn ngữ xem sao.'
                : 'Chưa có gì để ôn. Tra vài từ hoặc kiểm tra một đoạn văn, rồi quay lại đây.'}
            </p>
          </div>
        </div>
      </>
    )
  }

  return (
    <>
      <ReelsBackground />

      <LanguageFilterControls
        showFilters={showFilters}
        onToggleFilters={() => setShowFilters(!showFilters)}
        sourceLanguage={sourceLanguage}
        onSourceLanguageChange={handleSourceLanguageChange}
        targetLanguage={targetLanguage}
        onTargetLanguageChange={handleTargetLanguageChange}
        sort={sort}
        onCycleSort={handleCycleSort}
      />

      {/* Pull-to-refresh indicator */}
      {isRefreshing && (
        <div className="fixed top-20 left-1/2 transform -translate-x-1/2 z-50 bg-background/90 backdrop-blur-sm px-4 py-2 rounded-full shadow-lg">
          <RefreshCw className="h-5 w-5 animate-spin text-primary" />
        </div>
      )}

      {/* Scrollable container */}
      <div
        ref={setContainerEl}
        className={`fixed inset-0 top-16 snap-y snap-mandatory scrollbar-hide ${overlayOpen ? 'overflow-hidden' : 'overflow-y-scroll'}`}
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
      >
        {allItems.map((item) => (
          <div
            key={`${item.type}-${item.data.id}-p${item.pageIdx}-${item.itemIdx}`}
            className="h-full w-full snap-start flex items-center justify-center"
          >
            <DictionaryReelCard
              data={item.data}
              isVeiled={isVeiled}
              onToggleVeil={toggleVeil}
              onToggleRevealMode={handleToggleRevealMode}
              isDesktop={isDesktop}
              onDetailsOpenChange={setOverlayOpen}
              perCardReveal={perCardReveal}
            />
          </div>
        ))}

        {/* Loading indicator for infinite scroll */}
        {isFetchingNextPage && (
          <div className="h-full w-full snap-start flex items-center justify-center">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
          </div>
        )}

        {/* End of content indicator */}
        {!hasNextPage && allItems.length > 0 && (
          <div className="h-full w-full snap-start flex items-center justify-center">
            <div className="text-center space-y-4 p-8">
              <p className="text-muted-foreground">You've reached the end!</p>
            </div>
          </div>
        )}
      </div>
    </>
  )
}
