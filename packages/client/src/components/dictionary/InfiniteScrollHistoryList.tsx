import { useState, useRef, useCallback, useEffect } from 'react'
import { useInfiniteQuery, useQueryClient } from '@tanstack/react-query'
import { LANGUAGE } from '@practice/shared'
import { MoreVertical, Trash2 } from 'lucide-react'
import { toast } from 'sonner'
import type { Language, Word } from '@practice/shared'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Button } from '@/components/ui/button'
import { env } from '@/config/env'
import { Skeleton } from '@/components/ui/skeleton'
import { Separator } from '@/components/ui/separator'

type SearchHistoryItem = {
  id: string
  userId: string
  word: Word
  searchedAt: string
}

type SearchHistoryResponse = {
  searchHistory: Array<SearchHistoryItem>
  hasMore: boolean
}

const fetchHistoryPage = async ({
  pageParam = 1,
}: {
  pageParam?: number
}): Promise<SearchHistoryResponse> => {
  const response = await fetch(
    `${env.VITE_API_URL}/api/dictionary/history?page=${pageParam}&limit=20`,
    {
      method: 'GET',
      credentials: 'include',
    }
  )

  if (!response.ok) {
    throw new Error('Không tải được lịch sử tra từ')
  }

  return response.json()
}

export function InfiniteScrollHistoryList() {
  const {
    data,
    isLoading,
    isError,
    error,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = useInfiniteQuery({
    queryKey: ['dictionary-history'],
    queryFn: fetchHistoryPage,
    initialPageParam: 1,
    getNextPageParam: (lastPage, allPages) => {
      return lastPage.hasMore ? allPages.length + 1 : undefined
    },
  })

  const [selectedItem, setSelectedItem] = useState<SearchHistoryItem | null>(null)
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [isDeleting, setIsDeleting] = useState(false)

  const queryClient = useQueryClient()

  // Intersection Observer for infinite scroll
  const observerTarget = useRef<HTMLDivElement>(null)

  const handleObserver = useCallback(
    (entries: IntersectionObserverEntry[]) => {
      const [target] = entries
      if (target.isIntersecting && hasNextPage && !isFetchingNextPage) {
        fetchNextPage()
      }
    },
    [fetchNextPage, hasNextPage, isFetchingNextPage]
  )

  useEffect(() => {
    const element = observerTarget.current
    if (!element) return

    const observer = new IntersectionObserver(handleObserver, {
      threshold: 0.5,
      rootMargin: '100px',
    })

    observer.observe(element)

    return () => {
      observer.disconnect()
    }
  }, [handleObserver])

  const getLanguageLabel = (lang: Language) => {
    switch (lang) {
      case LANGUAGE.ENGLISH:
        return 'EN'
      case LANGUAGE.FRENCH:
        return 'FR'
      case LANGUAGE.VIETNAMESE:
        return 'VI'
      case LANGUAGE.SPANISH:
        return 'ES'
      case LANGUAGE.GERMAN:
        return 'DE'
      default:
        return lang
    }
  }

  const handleWordClick = (item: SearchHistoryItem) => {
    setSelectedItem(item)
    setIsDialogOpen(true)
  }

  const handleDelete = async (historyId: string) => {
    if (isDeleting) return

    setIsDeleting(true)
    try {
      const response = await fetch(
        `${env.VITE_API_URL}/api/dictionary/history/${historyId}`,
        {
          method: 'DELETE',
          credentials: 'include',
        }
      )

      if (!response.ok) {
        throw new Error('Không xoá được mục này')
      }

      toast.success('Đã xoá khỏi lịch sử')
      setIsDialogOpen(false)
      setSelectedItem(null)
      queryClient.invalidateQueries({ queryKey: ['dictionary-history'] })
    } catch (error) {
      console.error('Error deleting history:', error)
      toast.error('Không xoá được mục này')
    } finally {
      setIsDeleting(false)
    }
  }

  // Loading state
  if (isLoading) {
    return (
      <div className="grid gap-4">
        {[...Array(5)].map((_, i) => (
          <Card key={i}>
            <CardHeader>
              <Skeleton className="h-6 w-3/4" />
            </CardHeader>
          </Card>
        ))}
      </div>
    )
  }

  // Error state
  if (isError) {
    return (
      <Card>
        <CardContent className="pt-6">
          <p className="text-center text-destructive">
            Không tải được lịch sử tra từ:{' '}
            {error instanceof Error ? error.message : 'lỗi không rõ'}
          </p>
        </CardContent>
      </Card>
    )
  }

  const allHistory = data?.pages.flatMap((page) => page.searchHistory) ?? []

  return (
    <>
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
          <DialogHeader>
            <div className="flex items-center justify-between">
              <DialogTitle className="text-2xl sm:text-3xl">
                {selectedItem?.word.word || 'Đang tải...'}
              </DialogTitle>
              {selectedItem && (
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon" disabled={isDeleting}>
                      <MoreVertical className="h-4 w-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem
                      variant="destructive"
                      onClick={() => handleDelete(selectedItem.id)}
                      disabled={isDeleting}
                    >
                      <Trash2 className="h-4 w-4 mr-2" />
                      {isDeleting ? 'Đang xoá...' : 'Xoá'}
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              )}
            </div>
          </DialogHeader>

          {selectedItem && (
            <div className="space-y-4 sm:space-y-6">
              <div>
                <p className="text-lg sm:text-xl text-muted-foreground">
                  {selectedItem.word.translated}
                </p>
              </div>

              <Separator />

              {selectedItem.word.explains.map((explainItem, idx) => (
                <div key={idx} className="space-y-3">
                  <p className="text-muted-foreground">{explainItem.explain}</p>

                  {(explainItem.synonyms.length > 0 ||
                    explainItem.antonyms.length > 0) && (
                    <div className="flex flex-wrap gap-4 text-sm">
                      {explainItem.synonyms.length > 0 && (
                        <div>
                          <span className="font-semibold text-green-600 dark:text-green-400">
                            Đồng nghĩa:{' '}
                          </span>
                          <span className="text-muted-foreground">
                            {explainItem.synonyms.join(', ')}
                          </span>
                        </div>
                      )}
                      {explainItem.antonyms.length > 0 && (
                        <div>
                          <span className="font-semibold text-red-600 dark:text-red-400">
                            Trái nghĩa:{' '}
                          </span>
                          <span className="text-muted-foreground">
                            {explainItem.antonyms.join(', ')}
                          </span>
                        </div>
                      )}
                    </div>
                  )}

                  {explainItem.exampleSentences.length > 0 && (
                    <div className="space-y-3">
                      <h3 className="font-semibold text-sm text-muted-foreground">
                        Ví dụ
                      </h3>
                      {explainItem.exampleSentences.map((example, exampleIdx) => (
                        <div key={exampleIdx}>
                          <div className="border-l-4 border-primary pl-4 py-2">
                            <p className="font-medium">{example.sourceSentence}</p>
                            <p className="text-muted-foreground mt-1">
                              {example.targetTranslation}
                            </p>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}

                  {idx < selectedItem.word.explains.length - 1 && <Separator />}
                </div>
              ))}
            </div>
          )}
        </DialogContent>
      </Dialog>

      {allHistory.length === 0 ? (
        <Card>
          <CardContent className="pt-6">
            <p className="text-center text-muted-foreground">
              Chưa có lịch sử nào. Cứ tra vài từ, chúng sẽ được lưu lại ở đây.
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-3">
          {allHistory.map((item, index) => (
            <Card
              key={`${item.id}-${index}`}
              className="cursor-pointer hover:shadow-md transition-shadow"
              onClick={() => handleWordClick(item)}
            >
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <CardTitle className="text-xl">{item.word.word}</CardTitle>
                    <CardDescription className="text-base mt-1">
                      {item.word.translated}
                    </CardDescription>
                  </div>
                  <div className="flex items-center gap-2 text-xs text-muted-foreground ml-4">
                    <span className="font-medium px-2 py-1 bg-muted rounded">
                      {getLanguageLabel(item.word.sourceLanguage)}
                    </span>
                    <span>→</span>
                    <span className="font-medium px-2 py-1 bg-muted rounded">
                      {getLanguageLabel(item.word.targetLanguage)}
                    </span>
                  </div>
                </div>
              </CardHeader>
            </Card>
          ))}

          {/* Loading indicator for next page */}
          {isFetchingNextPage && (
            <div className="grid gap-4">
              {[...Array(3)].map((_, i) => (
                <Card key={i}>
                  <CardHeader>
                    <Skeleton className="h-6 w-3/4" />
                  </CardHeader>
                </Card>
              ))}
            </div>
          )}

          {/* Intersection observer target */}
          <div ref={observerTarget} className="h-4" />
        </div>
      )}
    </>
  )
}
