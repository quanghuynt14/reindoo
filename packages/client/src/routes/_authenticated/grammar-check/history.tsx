import { Link, createFileRoute } from '@tanstack/react-router'
import { useCallback, useEffect, useState } from 'react'
import { toast } from 'sonner'
import { 
  AlertCircle, 
  ArrowLeft,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Download,
  History,
  Loader2,
  MoreVertical,
  Search,
  Trash2,
} from 'lucide-react'
import { Button } from '@/components/ui/button'
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
import { Input } from '@/components/ui/input'
import { Separator } from '@/components/ui/separator'
import { env } from '@/config/env'
import { errorCategoryLabel, formatDateTime, languageLabel } from '@/lib/labels'

export const Route = createFileRoute('/_authenticated/grammar-check/history')({
  component: HistoryPage,
})

type GrammarCheckResult = {
  id: string
  userId: string
  originalText: string
  correctedText: string
  detectedLanguage: string
  grammarErrors: Array<{
    message: string
    category: string
    position: { start: number; end: number }
    suggestion: string
  }>
  createdAt: string
}

type HistoryData = {
  results: Array<GrammarCheckResult>
  total: number
  page: number
  totalPages: number
}

// Constants for responsive behavior
const MOBILE_BREAKPOINT = 640
const MOBILE_TRUNCATE_LENGTH = 60
const DESKTOP_TRUNCATE_LENGTH = 100
const MOBILE_PAGE_NUMBERS = 3
const DESKTOP_PAGE_NUMBERS = 5

// Type for legacy browsers that use deprecated MediaQueryList methods
type LegacyMediaQueryList = MediaQueryList & {
  addListener: (listener: (event: MediaQueryListEvent) => void) => void
  removeListener: (listener: (event: MediaQueryListEvent) => void) => void
}

function HistoryPage() {
  const [history, setHistory] = useState<HistoryData | null>(null)
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [searchInput, setSearchInput] = useState('')
  const [selectedCheck, setSelectedCheck] = useState<GrammarCheckResult | null>(null)
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [isDeleting, setIsDeleting] = useState(false)
  const [isMobile, setIsMobile] = useState(() => {
    if (typeof window === 'undefined' || typeof window.matchMedia === 'undefined') {
      // Mobile-first default when running in non-browser environments (e.g. SSR)
      return true
    }
    return window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT - 1}px)`).matches
  })

  // Track mobile state for responsive behavior using matchMedia
  useEffect(() => {
    if (typeof window === 'undefined' || typeof window.matchMedia === 'undefined') {
      return
    }

    const mediaQuery = window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT - 1}px)`)

    // Ensure state is in sync with the current query result
    setIsMobile(mediaQuery.matches)

    const handleChange = (event: MediaQueryListEvent) => {
      setIsMobile(event.matches)
    }

    // Modern browsers support addEventListener
    if ('addEventListener' in mediaQuery) {
      mediaQuery.addEventListener('change', handleChange)
    } else {
      // Fallback for older browsers using deprecated addListener
      const legacyMediaQuery = mediaQuery as LegacyMediaQueryList
      legacyMediaQuery.addListener(handleChange)
    }

    return () => {
      if ('removeEventListener' in mediaQuery) {
        mediaQuery.removeEventListener('change', handleChange)
      } else {
        const legacyMediaQuery = mediaQuery as LegacyMediaQueryList
        legacyMediaQuery.removeListener(handleChange)
      }
    }
  }, [])

  const fetchHistory = useCallback(async () => {
    setLoading(true)
    try {
      const params = new URLSearchParams({
        page: page.toString(),
        limit: '10',
        sortBy: 'createdAt',
        sortOrder: 'desc',
      })
      
      if (search) {
        params.append('search', search)
      }

      const response = await fetch(
        `${env.VITE_API_URL}/api/grammar-check/history?${params.toString()}`,
        {
          method: 'GET',
          credentials: 'include',
        }
      )

      if (!response.ok) {
        throw new Error('Không tải được lịch sử')
      }

      const data = await response.json()
      setHistory(data)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    } finally {
      setLoading(false)
    }
  }, [page, search])

  useEffect(() => {
    fetchHistory()
  }, [fetchHistory])

  const handleSearch = () => {
    setSearch(searchInput)
    setPage(1)
  }

  const handleExport = async (format: 'csv' | 'txt') => {
    try {
      const response = await fetch(
        `${env.VITE_API_URL}/api/grammar-check/export?format=${format}`,
        {
          method: 'GET',
          credentials: 'include',
        }
      )

      if (!response.ok) {
        throw new Error('Không xuất được dữ liệu')
      }

      const blob = await response.blob()
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `grammar-check-history.${format === 'csv' ? 'csv' : 'txt'}`
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)
      toast.success(`Exported successfully as ${format.toUpperCase()}`)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    }
  }

  const truncateText = (text: string, maxLength: number = 50) => {
    if (text.length <= maxLength) return text
    return text.substring(0, maxLength) + '...'
  }

  const handleCheckClick = (check: GrammarCheckResult) => {
    setSelectedCheck(check)
    setIsDialogOpen(true)
  }

  const handleCardKeyDown = (event: React.KeyboardEvent, check: GrammarCheckResult) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      handleCheckClick(check)
    }
  }

  const handleDelete = async (historyId: string) => {
    if (isDeleting) return

    setIsDeleting(true)
    try {
      const response = await fetch(`${env.VITE_API_URL}/api/grammar-check/history/${historyId}`, {
        method: 'DELETE',
        credentials: 'include',
      })

      if (!response.ok) {
        throw new Error('Không xoá được mục này')
      }

      toast.success('Đã xoá khỏi lịch sử')
      setIsDialogOpen(false)
      setSelectedCheck(null)
      // Refetch history
      fetchHistory()
    } catch (error) {
      console.error('Error deleting history:', error)
      toast.error('Không xoá được mục này')
    } finally {
      setIsDeleting(false)
    }
  }

  // Memoized truncate length based on mobile state
  const truncateLength = isMobile ? MOBILE_TRUNCATE_LENGTH : DESKTOP_TRUNCATE_LENGTH
  const pageNumbersToShow = isMobile ? MOBILE_PAGE_NUMBERS : DESKTOP_PAGE_NUMBERS

  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
        <div className="flex items-center gap-3">
          <History className="h-6 w-6 sm:h-8 sm:w-8" />
          <h1 className="text-2xl sm:text-3xl font-bold">Lịch sử kiểm tra ngữ pháp</h1>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button variant="outline" size="sm" onClick={() => handleExport('csv')}>
            <Download className="mr-2 h-4 w-4" />
            <span className="hidden sm:inline">Tải về CSV</span>
            <span className="sm:hidden">CSV</span>
          </Button>
          <Button variant="outline" size="sm" onClick={() => handleExport('txt')}>
            <Download className="mr-2 h-4 w-4" />
            <span className="hidden sm:inline">Tải về TXT</span>
            <span className="sm:hidden">TXT</span>
          </Button>
          <Link to="/grammar-check">
            <Button variant="outline" size="sm">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Quay lại
            </Button>
          </Link>
        </div>
      </div>

      {/* Search Bar */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle className="text-lg sm:text-xl">Tìm trong lịch sử</CardTitle>
          <CardDescription>
            Tìm theo nội dung văn bản hoặc theo ngôn ngữ
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col sm:flex-row gap-2">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                value={searchInput}
                onChange={(e) => setSearchInput(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                placeholder="Tìm..."
                className="pl-10"
              />
            </div>
            <div className="flex gap-2">
              <Button onClick={handleSearch} className="flex-1 sm:flex-none">Tìm</Button>
              {search && (
                <Button 
                  variant="outline" 
                  onClick={() => {
                    setSearch('')
                    setSearchInput('')
                    setPage(1)
                  }}
                  className="flex-1 sm:flex-none"
                >
                  Xoá bộ lọc
                </Button>
              )}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Dialog for showing full details */}
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
          <DialogHeader>
            <div className="flex items-center justify-between">
              <DialogTitle className="text-xl sm:text-2xl">
                Chi tiết lần kiểm tra
              </DialogTitle>
              {selectedCheck && (
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon" disabled={isDeleting}>
                      <MoreVertical className="h-4 w-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem
                      variant="destructive"
                      onClick={() => handleDelete(selectedCheck.id)}
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

          {selectedCheck && (
            <div className="space-y-4 sm:space-y-6">
              {/* Date and Language */}
              <div className="flex flex-col sm:flex-row sm:items-center gap-2 text-sm text-muted-foreground">
                <span>
                  {formatDateTime(selectedCheck.createdAt)}
                </span>
                <span className="hidden sm:inline">•</span>
                <span className="font-medium">
                  {languageLabel(selectedCheck.detectedLanguage)}
                </span>
              </div>

              <Separator />

              {/* Grammar Errors */}
              <div>
                <div className="flex items-center gap-2 mb-3">
                  {selectedCheck.grammarErrors.length === 0 ? (
                    <>
                      <CheckCircle2 className="h-5 w-5 text-green-500" />
                      <h3 className="font-semibold text-base sm:text-lg">Không có lỗi nào</h3>
                    </>
                  ) : (
                    <>
                      <AlertCircle className="h-5 w-5 text-yellow-500" />
                      <h3 className="font-semibold text-base sm:text-lg">
                        Những chỗ chưa đúng ({selectedCheck.grammarErrors.length})
                      </h3>
                    </>
                  )}
                </div>

                {selectedCheck.grammarErrors.length === 0 ? (
                  <p className="text-muted-foreground">
                    Đoạn văn này không có lỗi ngữ pháp nào.
                  </p>
                ) : (
                  <div className="space-y-3">
                    {selectedCheck.grammarErrors.map((error, index) => (
                      <div
                        key={index}
                        className="p-3 sm:p-4 border rounded-lg space-y-2"
                      >
                        <div className="flex items-start justify-between gap-2">
                          <p className="font-medium text-sm sm:text-base">{error.message}</p>
                          <span className="px-2 py-1 text-xs rounded-full bg-secondary whitespace-nowrap">
                            {errorCategoryLabel(error.category)}
                          </span>
                        </div>
                        <div className="flex flex-wrap items-center gap-2 text-sm">
                          <span className="px-2 py-0.5 rounded bg-red-500/10 text-red-700 dark:text-red-400 line-through decoration-red-500/60">
                            {selectedCheck.originalText.slice(error.position.start, error.position.end)}
                          </span>
                          <span className="text-muted-foreground">→</span>
                          <span className="px-2 py-0.5 rounded bg-green-500/10 text-green-700 dark:text-green-400 font-medium">
                            {error.suggestion}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <Separator />

              {/* Corrected Text */}
              <div>
                <h3 className="font-semibold text-base sm:text-lg mb-3">Văn bản đã sửa</h3>
                <div className="p-3 sm:p-4 bg-muted rounded-lg">
                  <p className="whitespace-pre-wrap text-sm sm:text-base">{selectedCheck.correctedText}</p>
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  className="mt-3"
                  onClick={async () => {
                    try {
                      if (!navigator.clipboard) {
                        toast.error('Trình duyệt này không hỗ trợ sao chép')
                        return
                      }
                      await navigator.clipboard.writeText(selectedCheck.correctedText)
                      toast.success('Đã sao chép văn bản đã sửa')
                    } catch (error) {
                      // Check for DOMException which is thrown for permission errors
                      let errorMessage = 'Không sao chép được'
                      
                      if (error instanceof DOMException && error.name === 'NotAllowedError') {
                        errorMessage = 'Trình duyệt chặn quyền sao chép. Hãy cho phép rồi thử lại.'
                      } else if (error instanceof Error && error.message.toLowerCase().includes('permission')) {
                        errorMessage = 'Trình duyệt chặn quyền sao chép. Hãy cho phép rồi thử lại.'
                      }
                      
                      toast.error(errorMessage)
                    }
                  }}
                >
                  Sao chép văn bản đã sửa
                </Button>
              </div>

              <Separator />

              {/* Original Text */}
              <div>
                <h3 className="font-semibold text-base sm:text-lg mb-3">Văn bản gốc</h3>
                <div className="p-3 sm:p-4 bg-muted rounded-lg">
                  <p className="whitespace-pre-wrap text-sm sm:text-base">{selectedCheck.originalText}</p>
                </div>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>

      {/* History List */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin" />
        </div>
      ) : !history || history.results.length === 0 ? (
        <Card>
          <CardContent className="py-12">
            <div className="text-center">
              <AlertCircle className="h-12 w-12 sm:h-16 sm:w-16 text-muted-foreground mx-auto mb-4" />
              <p className="text-muted-foreground">Chưa có lần kiểm tra nào</p>
            </div>
          </CardContent>
        </Card>
      ) : (
        <>
          <div className="space-y-3">
            {history.results.map((check) => (
              <Card
                key={check.id}
                className="cursor-pointer hover:shadow-md transition-shadow"
                onClick={() => handleCheckClick(check)}
                onKeyDown={(e) => handleCardKeyDown(e, check)}
                tabIndex={0}
                role="button"
                aria-label={`Xem chi tiết lần kiểm tra: ${truncateText(check.originalText, truncateLength)}`}
              >
                <CardHeader className="pb-3">
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex-1 min-w-0">
                      <CardTitle className="text-base sm:text-lg">
                        {truncateText(check.originalText, truncateLength)}
                      </CardTitle>
                      <CardDescription className="text-sm mt-2">
                        {formatDateTime(check.createdAt)}
                      </CardDescription>
                    </div>
                    <div className="flex flex-col items-end gap-2 text-xs">
                      <span className="font-medium px-2 py-1 bg-muted rounded whitespace-nowrap">
                        {languageLabel(check.detectedLanguage)}
                      </span>
                      <span className={`inline-flex items-center rounded-md px-2 py-1 font-medium whitespace-nowrap ${
                        check.grammarErrors.length === 0 
                          ? 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-400' 
                          : 'bg-yellow-50 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400'
                      }`}>
                        {check.grammarErrors.length === 0 ? (
                          <><CheckCircle2 className="h-3 w-3 mr-1" />Không lỗi</>
                        ) : (
                          <>{check.grammarErrors.length} lỗi</>
                        )}
                      </span>
                    </div>
                  </div>
                </CardHeader>
              </Card>
            ))}
          </div>

          {/* Pagination */}
          <Card className="mt-6">
            <CardContent className="py-4">
              <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
                <div className="text-sm text-muted-foreground text-center sm:text-left">
                  Đang xem {((history.page - 1) * 10) + 1}–{Math.min(history.page * 10, history.total)} trong {history.total} kết quả
                </div>
                <div className="flex flex-wrap items-center justify-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage(p => Math.max(1, p - 1))}
                    disabled={history.page === 1}
                  >
                    <ChevronLeft className="h-4 w-4" />
                    <span className="hidden sm:inline ml-1">Trước</span>
                  </Button>
                  <div className="flex items-center gap-1">
                    {/* Show different page numbers on desktop vs mobile */}
                    {Array.from({ length: Math.min(pageNumbersToShow, history.totalPages) }, (_, i) => {
                      const pageNum = i + 1
                      return (
                        <Button
                          key={pageNum}
                          variant={history.page === pageNum ? "default" : "outline"}
                          size="sm"
                          onClick={() => setPage(pageNum)}
                        >
                          {pageNum}
                        </Button>
                      )
                    })}
                    {history.totalPages > pageNumbersToShow && (
                      <>
                        <span className="px-2">...</span>
                        <Button
                          variant={history.page === history.totalPages ? "default" : "outline"}
                          size="sm"
                          onClick={() => setPage(history.totalPages)}
                        >
                          {history.totalPages}
                        </Button>
                      </>
                    )}
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage(p => Math.min(history.totalPages, p + 1))}
                    disabled={history.page === history.totalPages}
                  >
                    <span className="hidden sm:inline mr-1">Sau</span>
                    <ChevronRight className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  )
}
