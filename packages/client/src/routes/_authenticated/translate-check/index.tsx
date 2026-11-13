import { Link, createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { toast } from 'sonner'
import { AlertCircle, ArrowRight, CheckCircle2, Globe, Languages, Loader2, Star, Target } from 'lucide-react'
import type { TranslateCheckResult } from '@practice/shared'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { env } from '@/config/env'
import { languageLabel } from '@/lib/labels'

export const Route = createFileRoute('/_authenticated/translate-check/')({
  component: TranslateCheckPage,
})

// « tiếng Anh » en début de phrase, et les anciennes valeurs anglaises en base
// passent par la même table de correspondance.
const formatLanguageName = (language: string) => {
  const label = languageLabel(language)
  return label.charAt(0).toUpperCase() + label.slice(1)
}

function TranslateCheckPage() {
  const [originalText, setOriginalText] = useState('')
  const [translatedText, setTranslatedText] = useState('')
  const [result, setResult] = useState<TranslateCheckResult | null>(null)
  const [loading, setLoading] = useState(false)
  const [isStarred, setIsStarred] = useState(false)
  const [togglingStarStatus, setTogglingStarStatus] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!originalText.trim()) {
      toast.error('Bạn chưa nhập văn bản gốc')
      return
    }

    if (!translatedText.trim()) {
      toast.error('Bạn chưa nhập bản dịch')
      return
    }

    if (originalText.length > 5000) {
      toast.error('Văn bản gốc quá dài. Tối đa 5000 ký tự.')
      return
    }

    if (translatedText.length > 5000) {
      toast.error('Bản dịch quá dài. Tối đa 5000 ký tự.')
      return
    }

    setLoading(true)
    setResult(null)

    try {
      const response = await fetch(`${env.VITE_API_URL}/api/translate-check/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({ originalText, translatedText }),
      })

      if (!response.ok) {
        let errorMessage = 'Không đối chiếu được. Vui lòng thử lại.'
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

      const data: TranslateCheckResult = await response.json()
      setResult(data)
      // Check star status after getting the result
      checkStarStatus(data.id)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    } finally {
      setLoading(false)
    }
  }

  const checkStarStatus = async (translationCheckId: string) => {
    try {
      const response = await fetch(
        `${env.VITE_API_URL}/api/translate-check/starred/check?translationCheckId=${translationCheckId}`,
        {
          method: 'GET',
          credentials: 'include',
        }
      )

      if (response.ok) {
        const data = await response.json()
        setIsStarred(data.starred)
      }
    } catch (err) {
      // Silently fail - starring is not critical
    }
  }

  const toggleStar = async () => {
    if (!result) return

    setTogglingStarStatus(true)

    try {
      const response = await fetch(`${env.VITE_API_URL}/api/translate-check/starred/toggle`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          translationCheckId: result.id,
        }),
      })

      if (!response.ok) {
        throw new Error('Không lưu được')
      }

      const data = await response.json()
      setIsStarred(data.starred)
      toast.success(data.starred ? 'Đã lưu' : 'Đã bỏ lưu')
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    } finally {
      setTogglingStarStatus(false)
    }
  }

  const handleClear = () => {
    setOriginalText('')
    setTranslatedText('')
    setResult(null)
    setIsStarred(false)
  }

  return (
    <div className="container mx-auto px-4 py-4 sm:py-8 max-w-6xl">
      {/* Header */}
      <div className="flex items-center justify-between mb-4 sm:mb-6">
        <div className="flex items-center gap-2 sm:gap-3">
          <div className="p-2 rounded-lg bg-primary/10">
            <Languages className="h-5 w-5 sm:h-6 sm:w-6 text-primary" />
          </div>
          <h1 className="text-xl sm:text-2xl md:text-3xl font-bold">Đối chiếu bản dịch</h1>
        </div>
        <div className="flex items-center gap-2">
          <Link to="/translate-check/analysis">
            <Button variant="outline" size="sm">
              <Target className="mr-2 h-4 w-4" />
              Phân tích
            </Button>
          </Link>
          {result && (
            <Button
              variant="ghost"
              size="sm"
              onClick={toggleStar}
              disabled={togglingStarStatus}
              aria-label={isStarred ? 'Bỏ lưu lần đối chiếu này' : 'Lưu lần đối chiếu này'}
              className="shrink-0"
            >
              <Star
                className={`h-5 w-5 ${isStarred ? 'fill-yellow-400 text-yellow-400' : 'text-muted-foreground'}`}
              />
            </Button>
          )}
        </div>
      </div>

      <div className="grid gap-4 sm:gap-6 lg:grid-cols-2">
        {/* Input Section */}
        <Card className="h-fit">
          <CardHeader className="pb-3 sm:pb-6">
            <CardTitle className="text-base sm:text-lg">Văn bản của bạn</CardTitle>
            <CardDescription className="text-xs sm:text-sm">
              Nhập văn bản gốc và bản dịch của bạn. Lỗi sẽ được giải thích bằng tiếng Việt.
              Tối đa 5000 ký tự mỗi ô.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-3 sm:space-y-4">
              <div className="space-y-1.5 sm:space-y-2">
                <label htmlFor="originalText" className="text-xs sm:text-sm font-medium">
                  Văn bản gốc
                </label>
                <Textarea
                  id="originalText"
                  value={originalText}
                  onChange={(e) => setOriginalText(e.target.value)}
                  placeholder="Nhập văn bản gốc ở đây..."
                  className="min-h-[120px] sm:min-h-[150px] resize-none text-sm sm:text-base"
                  disabled={loading}
                />
                <span className="text-xs text-muted-foreground">
                  {originalText.length} / 5000 ký tự
                </span>
              </div>

              <div className="space-y-1.5 sm:space-y-2">
                <label htmlFor="translatedText" className="text-xs sm:text-sm font-medium">
                  Bản dịch của bạn
                </label>
                <Textarea
                  id="translatedText"
                  value={translatedText}
                  onChange={(e) => setTranslatedText(e.target.value)}
                  placeholder="Nhập bản dịch ở đây..."
                  className="min-h-[120px] sm:min-h-[150px] resize-none text-sm sm:text-base"
                  disabled={loading}
                />
                <span className="text-xs text-muted-foreground">
                  {translatedText.length} / 5000 ký tự
                </span>
              </div>

              <div className="flex flex-col sm:flex-row gap-2 w-full sm:w-auto pt-2">
                <Button
                  type="button"
                  variant="outline"
                  onClick={handleClear}
                  disabled={loading || (!originalText && !translatedText)}
                  className="w-full sm:w-auto text-sm"
                >
                  Xoá
                </Button>
                <Button 
                  type="submit" 
                  disabled={loading || !originalText.trim() || !translatedText.trim()} 
                  className="w-full sm:w-auto text-sm"
                >
                  {loading ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Đang đối chiếu...
                    </>
                  ) : (
                    <>
                      <Languages className="mr-2 h-4 w-4" />
                      Đối chiếu
                    </>
                  )}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>

        {/* Results Section */}
        <div className="space-y-4 sm:space-y-6">
          {result ? (
            <>
              {/* Detected Languages Card - Enhanced for Mobile */}
              <Card className="border-2 border-primary/20 bg-linear-to-br from-primary/5 to-transparent">
                <CardHeader className="pb-3 sm:pb-4">
                  <CardTitle className="text-sm sm:text-base flex items-center gap-2">
                    <Globe className="h-4 w-4 text-primary" />
                    Ngôn ngữ nhận ra
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="flex flex-col sm:flex-row items-start sm:items-center gap-3 sm:gap-4">
                    {/* Original Language */}
                    <div className="flex-1 w-full">
                      <div className="flex items-center gap-2 mb-1">
                        <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                          <span className="text-xs font-bold text-primary">1</span>
                        </div>
                        <p className="text-xs text-muted-foreground">Bản gốc</p>
                      </div>
                      <p className="text-base sm:text-lg font-bold text-primary ml-10">
                        {formatLanguageName(result.detectedOriginalLanguage)}
                      </p>
                    </div>

                    {/* Arrow Icon - Hidden on mobile, shown on desktop */}
                    <div className="hidden sm:block">
                      <ArrowRight className="h-5 w-5 text-muted-foreground" />
                    </div>

                    {/* Translated Language */}
                    <div className="flex-1 w-full">
                      <div className="flex items-center gap-2 mb-1">
                        <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                          <span className="text-xs font-bold text-primary">2</span>
                        </div>
                        <p className="text-xs text-muted-foreground">Bản dịch</p>
                      </div>
                      <p className="text-base sm:text-lg font-bold text-primary ml-10">
                        {formatLanguageName(result.detectedTranslatedLanguage)}
                      </p>
                    </div>
                  </div>
                </CardContent>
              </Card>

              {/* Translation Errors - Enhanced for Mobile */}
              <Card className={result.translationErrors.length === 0 ? 'border-green-200 bg-green-50/50' : 'border-yellow-200 bg-yellow-50/50'}>
                <CardHeader className="pb-3 sm:pb-4">
                  <CardTitle className="text-sm sm:text-base flex items-center gap-2 flex-wrap">
                    {result.translationErrors.length === 0 ? (
                      <>
                        <CheckCircle2 className="h-5 w-5 text-green-600 shrink-0" />
                        <span className="text-green-700 text-sm sm:text-base">Không có lỗi nào</span>
                      </>
                    ) : (
                      <>
                        <AlertCircle className="h-5 w-5 text-yellow-600 shrink-0" />
                        <span className="text-yellow-700 text-sm sm:text-base">
                          {result.translationErrors.length} lỗi dịch
                        </span>
                      </>
                    )}
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  {result.translationErrors.length === 0 ? (
                    <div className="flex items-start gap-3 p-3 sm:p-4 bg-white/50 rounded-lg">
                      <CheckCircle2 className="h-5 w-5 text-green-600 shrink-0 mt-0.5" />
                      <div>
                        <p className="text-sm sm:text-base font-medium text-green-900">Bản dịch chuẩn!</p>
                        <p className="text-xs sm:text-sm text-green-700 mt-1">
                          Không tìm thấy lỗi nào trong bản dịch của bạn.
                        </p>
                      </div>
                    </div>
                  ) : (
                    <div className="space-y-2 sm:space-y-3">
                      {result.translationErrors.map((error, index) => (
                        <div
                          key={`${index}-${error.message.substring(0, 20)}`}
                          className="p-3 sm:p-4 bg-white border border-yellow-200 rounded-lg hover:shadow-sm transition-shadow"
                        >
                          <div className="flex items-start gap-2 mb-2">
                            <span className="inline-flex items-center justify-center w-5 h-5 rounded-full bg-yellow-100 text-yellow-700 text-xs font-bold shrink-0">
                              {index + 1}
                            </span>
                            <p className="font-medium text-sm sm:text-base text-gray-900 flex-1">{error.message}</p>
                          </div>
                          {(error.positions.original.length > 0 || error.positions.translated.length > 0) && (
                            <div className="ml-7 space-y-1 text-xs sm:text-sm text-muted-foreground">
                              {error.positions.original.length > 0 && (
                                <p className="flex flex-wrap items-center gap-1">
                                  <span className="font-medium text-gray-700">Bản gốc:</span>
                                  <span className="text-gray-600">vị trí {error.positions.original.join(', ')}</span>
                                </p>
                              )}
                              {error.positions.translated.length > 0 && (
                                <p className="flex flex-wrap items-center gap-1">
                                  <span className="font-medium text-gray-700">Bản dịch:</span>
                                  <span className="text-gray-600">vị trí {error.positions.translated.join(', ')}</span>
                                </p>
                              )}
                            </div>
                          )}
                        </div>
                      ))}
                    </div>
                  )}
                </CardContent>
              </Card>

              {/* Corrected Translation Display - Only shown when there are errors */}
              {result.translationErrors.length > 0 && result.correctedTranslation.trim() !== '' && (
                <Card className="border-green-200 bg-green-50/30">
                  <CardHeader className="pb-3 sm:pb-4">
                    <CardTitle className="text-sm sm:text-base flex items-center gap-2 text-green-700">
                      <CheckCircle2 className="h-4 w-4" />
                      Bản dịch đã sửa
                    </CardTitle>
                    <CardDescription className="text-xs">Gợi ý sửa của máy</CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="p-3 sm:p-4 bg-white rounded-lg border border-green-200">
                      <p className="whitespace-pre-wrap text-sm sm:text-base leading-relaxed">{result.correctedTranslation}</p>
                    </div>
                  </CardContent>
                </Card>
              )}

              {/* Text Comparison Section */}
              <div className="grid gap-4">
                {/* Original Text Display */}
                <Card>
                  <CardHeader className="pb-3 sm:pb-4">
                    <CardTitle className="text-sm sm:text-base flex items-center gap-2">
                      <div className="w-6 h-6 rounded bg-blue-100 flex items-center justify-center shrink-0">
                        <span className="text-xs font-bold text-blue-700">1</span>
                      </div>
                      Văn bản gốc
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="p-3 sm:p-4 bg-muted/50 rounded-lg border">
                      <p className="whitespace-pre-wrap text-sm sm:text-base leading-relaxed">{result.originalText}</p>
                    </div>
                  </CardContent>
                </Card>

                {/* Your Translated Text Display */}
                <Card>
                  <CardHeader className="pb-3 sm:pb-4">
                    <CardTitle className="text-sm sm:text-base flex items-center gap-2">
                      <div className="w-6 h-6 rounded bg-purple-100 flex items-center justify-center shrink-0">
                        <span className="text-xs font-bold text-purple-700">2</span>
                      </div>
                      Bản dịch của bạn
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="p-3 sm:p-4 bg-muted/50 rounded-lg border">
                      <p className="whitespace-pre-wrap text-sm sm:text-base leading-relaxed">{result.translatedText}</p>
                    </div>
                  </CardContent>
                </Card>
              </div>
            </>
          ) : (
            <Card className="border-dashed">
              <CardContent className="flex flex-col items-center justify-center py-10 sm:py-12 px-4">
                <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-primary/10 flex items-center justify-center mb-4">
                  <Languages className="h-8 w-8 sm:h-10 sm:w-10 text-primary" />
                </div>
                <p className="text-sm sm:text-base text-muted-foreground text-center max-w-sm">
                  Nhập cả hai ô rồi bấm <span className="font-semibold">« Đối chiếu »</span> để xem kết quả ở đây
                </p>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  )
}
