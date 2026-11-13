import { Link, createFileRoute } from '@tanstack/react-router'
import { useEffect, useRef, useState } from 'react'
import { toast } from 'sonner'
import {
  AlertCircle,
  BarChart3,
  Check,
  CheckCircle2,
  Copy,
  FileCheck,
  Loader2,
} from 'lucide-react'
import type { GrammarCheckResult, GrammarError } from '@practice/shared'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { env } from '@/config/env'
import { errorCategoryLabel } from '@/lib/labels'

export const Route = createFileRoute('/_authenticated/grammar-check/')({
  component: GrammarCheckPage,
})

const MAX_LENGTH = 5000

function excerptOf(text: string, error: GrammarError) {
  const start = Math.max(0, Math.min(error.position.start, text.length))
  const end = Math.max(0, Math.min(error.position.end, text.length))
  return end > start ? text.slice(start, end) : ''
}

function GrammarCheckPage() {
  const [text, setText] = useState('')
  const [result, setResult] = useState<GrammarCheckResult | null>(null)
  const [loading, setLoading] = useState(false)
  const [copied, setCopied] = useState(false)
  const resultsRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!copied) return
    const timer = setTimeout(() => setCopied(false), 2000)
    return () => clearTimeout(timer)
  }, [copied])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!text.trim()) {
      toast.error('Bạn chưa nhập văn bản nào')
      return
    }

    if (text.length > MAX_LENGTH) {
      toast.error(`Văn bản quá dài. Tối đa ${MAX_LENGTH} ký tự.`)
      return
    }

    setLoading(true)
    setResult(null)

    try {
      const response = await fetch(`${env.VITE_API_URL}/api/grammar-check/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({ text }),
      })

      if (!response.ok) {
        let errorMessage = 'Không kiểm tra được. Vui lòng thử lại.'
        const contentType = response.headers.get('content-type') || ''

        if (contentType.includes('application/json')) {
          try {
            const errorData = await response.json()
            if (errorData && typeof errorData === 'object' && 'message' in errorData) {
              errorMessage = errorData.message
            }
          } catch {
            // Keep default errorMessage if JSON parsing fails
          }
        } else {
          try {
            const errorText = await response.text()
            if (errorText) {
              errorMessage = errorText
            }
          } catch {
            // Keep default errorMessage if reading text fails
          }
        }

        throw new Error(errorMessage)
      }

      const data: GrammarCheckResult = await response.json()
      setResult(data)
      // On mobile the results sit below the form: bring them into view.
      requestAnimationFrame(() => {
        resultsRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      })
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    } finally {
      setLoading(false)
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter' && !loading && text.trim()) {
      handleSubmit(e)
    }
  }

  const handleCopy = async () => {
    if (!result) return

    try {
      await navigator.clipboard.writeText(result.correctedText)
      setCopied(true)
    } catch (error) {
      toast.error('Không sao chép được')
    }
  }

  const handleClear = () => {
    setText('')
    setResult(null)
  }

  const errors = result?.grammarErrors ?? []
  const hasErrors = errors.length > 0
  const nearLimit = text.length > MAX_LENGTH * 0.9

  return (
    <div className="container mx-auto px-4 py-8 max-w-6xl">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
        <div className="flex items-center gap-3">
          <FileCheck className="h-6 w-6 sm:h-8 sm:w-8" />
          <h1 className="text-2xl sm:text-3xl font-bold">Kiểm tra ngữ pháp</h1>
        </div>
        <div className="flex flex-wrap gap-2">
          <Link to="/grammar-check/analytics">
            <Button variant="outline" size="sm">
              <BarChart3 className="mr-2 h-4 w-4" />
              <span className="hidden sm:inline">Thống kê</span>
              <span className="sm:hidden">Số liệu</span>
            </Button>
          </Link>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2 lg:items-start">
        {/* Input Section */}
        <Card className="lg:sticky lg:top-6">
          <CardHeader>
            <CardTitle className="text-lg sm:text-xl">Văn bản của bạn</CardTitle>
            <CardDescription>
              Gõ hoặc dán đoạn văn tiếng nước ngoài vào đây. Lỗi sẽ được giải thích bằng
              tiếng Việt. Tối đa {MAX_LENGTH} ký tự.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <Textarea
                value={text}
                onChange={(e) => setText(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="Nhập văn bản ở đây..."
                className="min-h-[250px] sm:min-h-[300px] resize-none"
                disabled={loading}
              />
              <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2">
                <span
                  className={`text-sm ${text.length > MAX_LENGTH ? 'text-destructive font-medium' : nearLimit ? 'text-yellow-600 dark:text-yellow-500' : 'text-muted-foreground'}`}
                >
                  {text.length} / {MAX_LENGTH} ký tự
                </span>
                <div className="flex gap-2 w-full sm:w-auto">
                  <Button
                    type="button"
                    variant="outline"
                    onClick={handleClear}
                    disabled={loading || !text}
                    className="flex-1 sm:flex-none"
                    size="sm"
                  >
                    Xoá
                  </Button>
                  <Button
                    type="submit"
                    disabled={loading || !text.trim() || text.length > MAX_LENGTH}
                    className="flex-1 sm:flex-none"
                    size="sm"
                  >
                    {loading ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        Đang kiểm tra...
                      </>
                    ) : (
                      <>
                        <FileCheck className="mr-2 h-4 w-4" />
                        Kiểm tra
                      </>
                    )}
                  </Button>
                </div>
              </div>
              <p className="hidden sm:block text-xs text-muted-foreground">
                Nhấn <kbd className="px-1 py-0.5 rounded border bg-muted font-mono">Ctrl</kbd> +{' '}
                <kbd className="px-1 py-0.5 rounded border bg-muted font-mono">Enter</kbd> để kiểm tra
              </p>
            </form>
          </CardContent>
        </Card>

        {/* Results Section */}
        <div ref={resultsRef} className="space-y-6">
          {loading ? (
            <Card>
              <CardHeader>
                <Skeleton className="h-5 w-40" />
              </CardHeader>
              <CardContent className="space-y-3">
                <Skeleton className="h-4 w-full" />
                <Skeleton className="h-4 w-11/12" />
                <Skeleton className="h-4 w-9/12" />
                <Skeleton className="h-9 w-36 mt-2" />
              </CardContent>
            </Card>
          ) : result ? (
            <>
              {/* Corrected text — the answer people came for, so it comes first */}
              <Card className={hasErrors ? undefined : 'border-green-500/40'}>
                <CardHeader>
                  <CardTitle className="text-base sm:text-lg flex flex-wrap items-center gap-2">
                    {hasErrors ? (
                      <>
                        <FileCheck className="h-4 w-4 sm:h-5 sm:w-5" />
                        Văn bản đã sửa
                        <Badge variant="destructive">Đã sửa {errors.length} lỗi</Badge>
                      </>
                    ) : (
                      <>
                        <CheckCircle2 className="h-4 w-4 sm:h-5 sm:w-5 text-green-600 dark:text-green-500" />
                        Không có lỗi nào
                      </>
                    )}
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="p-3 sm:p-4 bg-muted rounded-lg">
                    <p className="whitespace-pre-wrap text-sm sm:text-base">{result.correctedText}</p>
                  </div>
                  <div>
                    <Button variant="outline" size="sm" onClick={handleCopy}>
                      {copied ? (
                        <>
                          <Check className="mr-2 h-4 w-4 text-green-600 dark:text-green-500" />
                          Đã sao chép
                        </>
                      ) : (
                        <>
                          <Copy className="mr-2 h-4 w-4" />
                          Sao chép
                        </>
                      )}
                    </Button>
                  </div>
                </CardContent>
              </Card>

              {/* Errors — only worth a card when there is something to fix */}
              {hasErrors && (
                <Card>
                  <CardHeader>
                    <CardTitle className="text-base sm:text-lg flex items-center gap-2">
                      <AlertCircle className="h-4 w-4 sm:h-5 sm:w-5 text-yellow-500" />
                      Những chỗ chưa đúng ({errors.length})
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <ol className="space-y-3 sm:space-y-4">
                      {errors.map((error, index) => {
                        const excerpt = excerptOf(result.originalText, error)

                        return (
                          <li
                            key={index}
                            className="p-3 sm:p-4 border rounded-lg space-y-2 transition-colors hover:bg-accent/50"
                          >
                            <div className="flex items-start justify-between gap-2">
                              <p className="font-medium text-sm sm:text-base">
                                <span className="text-muted-foreground mr-2">{index + 1}.</span>
                                {error.message}
                              </p>
                              <Badge variant="outline" className="shrink-0">
                                {errorCategoryLabel(error.category)}
                              </Badge>
                            </div>
                            <div className="flex flex-wrap items-center gap-2 text-sm">
                              {excerpt && (
                                <span className="px-2 py-0.5 rounded bg-red-500/10 text-red-700 dark:text-red-400 line-through decoration-red-500/60">
                                  {excerpt}
                                </span>
                              )}
                              {excerpt && <span className="text-muted-foreground">→</span>}
                              <span className="px-2 py-0.5 rounded bg-green-500/10 text-green-700 dark:text-green-400 font-medium">
                                {error.suggestion}
                              </span>
                            </div>
                          </li>
                        )
                      })}
                    </ol>
                  </CardContent>
                </Card>
              )}
            </>
          ) : (
            <Card>
              <CardContent className="flex flex-col items-center justify-center py-12">
                <FileCheck className="h-12 w-12 sm:h-16 sm:w-16 text-muted-foreground mb-4" />
                <p className="text-sm sm:text-base text-muted-foreground text-center">
                  Nhập văn bản rồi bấm « Kiểm tra » để xem kết quả ở đây
                </p>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  )
}
