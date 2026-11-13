import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { LANGUAGE   } from '@practice/shared'
import { AlertCircle, CheckCircle2, Languages, Star } from 'lucide-react'
import { toast } from 'sonner'
import type {Language, Word} from '@practice/shared';
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
import { Button } from '@/components/ui/button'
import { env } from '@/config/env'
import { Skeleton } from '@/components/ui/skeleton'
import { Snowfall } from '@/components/Snowfall'
import { Separator } from '@/components/ui/separator'
import { errorCategoryLabel, formatDateTime, languageLabel } from '@/lib/labels'

type StarredType = 'dictionary' | 'grammar' | 'translation'

const TRUNCATE_TEXT_LENGTH = 100

// Helper function to get user-friendly error messages
const getErrorMessage = (response: Response): string => {
  if (response.status === 401) {
    return 'Bạn cần đăng nhập để làm việc này'
  }
  if (response.status === 404) {
    return 'Không tìm thấy mục này'
  }
  if (response.status === 500) {
    return 'Máy chủ gặp sự cố. Vui lòng thử lại sau'
  }
  if (!response.ok) {
    return `Failed to complete action (${response.status})`
  }
  return 'Có lỗi xảy ra'
}

type StarredWordItem = {
  userId: string
  word: Word
  starredAt: string
}

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

type StarredGrammarCheckItem = {
  userId: string
  grammarCheck: GrammarCheckResult
  starredAt: string
}

type TranslateCheckResult = {
  id: string
  userId: string
  originalText: string
  translatedText: string
  detectedOriginalLanguage: string
  detectedTranslatedLanguage: string
  translationErrors: Array<{
    message: string
    positions: {
      original: Array<number>
      translated: Array<number>
    }
  }>
  correctedTranslation: string
  createdAt: string
}

type StarredTranslationCheckItem = {
  userId: string
  translationCheck: TranslateCheckResult
  starredAt: string
}

const fetchStarredWords = async (): Promise<Array<StarredWordItem>> => {
  const response = await fetch(`${env.VITE_API_URL}/api/dictionary/starred`, {
    method: 'GET',
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error('Không tải được danh sách từ đã lưu')
  }

  const data = await response.json()
  return data.starredWords
}

const fetchStarredGrammarChecks = async (): Promise<Array<StarredGrammarCheckItem>> => {
  const response = await fetch(`${env.VITE_API_URL}/api/grammar-check/starred`, {
    method: 'GET',
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error('Không tải được danh sách bài kiểm tra đã lưu')
  }

  const data = await response.json()
  return data.starredGrammarChecks
}

const fetchStarredTranslationChecks = async (): Promise<Array<StarredTranslationCheckItem>> => {
  const response = await fetch(`${env.VITE_API_URL}/api/translate-check/starred`, {
    method: 'GET',
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error('Không tải được danh sách bản dịch đã lưu')
  }

  const data = await response.json()
  return data.starredTranslationChecks
}

export const Route = createFileRoute('/_authenticated/starred')({
  component: CentralizedStarred,
})

const formatLanguageName = (language: string) => {
  const label = languageLabel(language)
  return label.charAt(0).toUpperCase() + label.slice(1)
}

function CentralizedStarred() {
  const [selectedType, setSelectedType] = useState<StarredType>('dictionary')
  const [selectedWord, setSelectedWord] = useState<Word | null>(null)
  const [selectedGrammarItem, setSelectedGrammarItem] = useState<GrammarCheckResult | null>(null)
  const [selectedTranslationItem, setSelectedTranslationItem] = useState<TranslateCheckResult | null>(null)
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [removingId, setRemovingId] = useState<string | null>(null)

  const { data: starredWords, isLoading: isWordsLoading, isError: isWordsError, refetch: refetchWords } = useQuery({
    queryKey: ['starred-words'],
    queryFn: fetchStarredWords,
    enabled: selectedType === 'dictionary',
  })

  const { data: starredGrammarChecks, isLoading: isGrammarLoading, isError: isGrammarError, refetch: refetchGrammar } = useQuery({
    queryKey: ['starred-grammar-checks'],
    queryFn: fetchStarredGrammarChecks,
    enabled: selectedType === 'grammar',
  })

  const { data: starredTranslationChecks, isLoading: isTranslationLoading, isError: isTranslationError, refetch: refetchTranslation } = useQuery({
    queryKey: ['starred-translation-checks'],
    queryFn: fetchStarredTranslationChecks,
    enabled: selectedType === 'translation',
  })

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

  const handleWordClick = (item: StarredWordItem) => {
    setSelectedWord(item.word)
    setIsDialogOpen(true)
  }

  const handleGrammarClick = (item: StarredGrammarCheckItem) => {
    setSelectedGrammarItem(item.grammarCheck)
    setIsDialogOpen(true)
  }

  const handleTranslationClick = (item: StarredTranslationCheckItem) => {
    setSelectedTranslationItem(item.translationCheck)
    setIsDialogOpen(true)
  }

  const handleDialogChange = (open: boolean) => {
    setIsDialogOpen(open)
    // Clear selected items when dialog closes to prevent stale data
    if (!open) {
      setSelectedWord(null)
      setSelectedGrammarItem(null)
      setSelectedTranslationItem(null)
    }
  }

  const handleUnstarWord = async (wordItem: StarredWordItem, event: React.MouseEvent) => {
    event.stopPropagation()
    
    setRemovingId(wordItem.word.id)

    try {
      const response = await fetch(`${env.VITE_API_URL}/api/dictionary/starred/toggle`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          wordId: wordItem.word.id,
        }),
      })

      if (!response.ok) {
        const errorMessage = getErrorMessage(response)
        throw new Error(errorMessage)
      }

      toast.success('Đã bỏ lưu từ này')
      await refetchWords()
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    } finally {
      setRemovingId(null)
    }
  }

  const handleUnstarGrammarCheck = async (grammarItem: StarredGrammarCheckItem, event: React.MouseEvent) => {
    event.stopPropagation()
    
    setRemovingId(grammarItem.grammarCheck.id)

    try {
      const response = await fetch(`${env.VITE_API_URL}/api/grammar-check/starred/toggle`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          grammarCheckId: grammarItem.grammarCheck.id,
        }),
      })

      if (!response.ok) {
        const errorMessage = getErrorMessage(response)
        throw new Error(errorMessage)
      }

      toast.success('Đã bỏ lưu bài kiểm tra này')
      await refetchGrammar()
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    } finally {
      setRemovingId(null)
    }
  }

  const handleUnstarTranslationCheck = async (translationItem: StarredTranslationCheckItem, event: React.MouseEvent) => {
    event.stopPropagation()
    
    setRemovingId(translationItem.translationCheck.id)

    try {
      const response = await fetch(`${env.VITE_API_URL}/api/translate-check/starred/toggle`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          translationCheckId: translationItem.translationCheck.id,
        }),
      })

      if (!response.ok) {
        const errorMessage = getErrorMessage(response)
        throw new Error(errorMessage)
      }

      toast.success('Đã bỏ lưu bản dịch này')
      await refetchTranslation()
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    } finally {
      setRemovingId(null)
    }
  }

  const truncateText = (text: string, maxLength: number = TRUNCATE_TEXT_LENGTH) => {
    if (text.length <= maxLength) return text
    return text.substring(0, maxLength) + '...'
  }

  const isLoading = selectedType === 'dictionary' ? isWordsLoading : selectedType === 'grammar' ? isGrammarLoading : isTranslationLoading
  const isError = selectedType === 'dictionary' ? isWordsError : selectedType === 'grammar' ? isGrammarError : isTranslationError

  return (
    <>
      <div className="aurora-background">
        <div className="aurora-layer"></div>
      </div>
      <Snowfall />
      <div className="container mx-auto max-w-4xl pt-24 px-4">
        <div className="space-y-6">
          <div className="flex items-center gap-3">
            <Star className="h-8 w-8 text-yellow-400 fill-yellow-400" />
            <h1 className="text-3xl font-bold tracking-tight">Đã lưu</h1>
          </div>

          {/* Filter Buttons */}
          <Card>
            <CardContent className="pt-6">
              <div className="flex flex-wrap gap-2">
                <Button
                  variant={selectedType === 'dictionary' ? 'default' : 'outline'}
                  onClick={() => setSelectedType('dictionary')}
                  className="flex-1 sm:flex-none"
                >
                  Từ điển
                </Button>
                <Button
                  variant={selectedType === 'grammar' ? 'default' : 'outline'}
                  onClick={() => setSelectedType('grammar')}
                  className="flex-1 sm:flex-none"
                >
                  Ngữ pháp
                </Button>
                <Button
                  variant={selectedType === 'translation' ? 'default' : 'outline'}
                  onClick={() => setSelectedType('translation')}
                  className="flex-1 sm:flex-none"
                >
                  Bản dịch
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Dictionary Modal */}
          {selectedType === 'dictionary' && (
            <Dialog open={isDialogOpen} onOpenChange={handleDialogChange}>
              <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
                <DialogHeader>
                  <DialogTitle className="text-2xl sm:text-3xl">
                    {selectedWord?.word || 'Đang tải...'}
                  </DialogTitle>
                </DialogHeader>

                {selectedWord && (
                  <div className="space-y-4 sm:space-y-6">
                    <div>
                      <p className="text-lg sm:text-xl text-muted-foreground">
                        {selectedWord.translated}
                      </p>
                    </div>

                    <Separator />

                    {selectedWord.explains.map((explainItem, idx) => (
                      <div key={`${explainItem.explain}-${idx}`} className="space-y-3">
                        <p className="text-muted-foreground">{explainItem.explain}</p>

                        {(explainItem.synonyms.length > 0 || explainItem.antonyms.length > 0) && (
                          <div className="flex flex-wrap gap-4 text-sm">
                            {explainItem.synonyms.length > 0 && (
                              <div>
                                <span className="font-semibold text-green-600 dark:text-green-400">Đồng nghĩa: </span>
                                <span className="text-muted-foreground">{explainItem.synonyms.join(', ')}</span>
                              </div>
                            )}
                            {explainItem.antonyms.length > 0 && (
                              <div>
                                <span className="font-semibold text-red-600 dark:text-red-400">Trái nghĩa: </span>
                                <span className="text-muted-foreground">{explainItem.antonyms.join(', ')}</span>
                              </div>
                            )}
                          </div>
                        )}

                        {explainItem.exampleSentences.length > 0 && (
                          <div className="space-y-3">
                            <h3 className="font-semibold text-sm text-muted-foreground">Ví dụ</h3>
                            {explainItem.exampleSentences.map((example, exampleIdx) => (
                              <div key={`${example.sourceSentence}-${example.targetTranslation}-${exampleIdx}`}>
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

                        {idx < selectedWord.explains.length - 1 && <Separator />}
                      </div>
                    ))}
                  </div>
                )}
              </DialogContent>
            </Dialog>
          )}

          {/* Grammar Modal */}
          {selectedType === 'grammar' && (
            <Dialog open={isDialogOpen} onOpenChange={handleDialogChange}>
              <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
                <DialogHeader>
                  <DialogTitle className="text-xl sm:text-2xl">
                    Chi tiết lần kiểm tra ngữ pháp
                  </DialogTitle>
                </DialogHeader>

                {selectedGrammarItem && (
                  <div className="space-y-4 sm:space-y-6">
                    <div className="flex flex-col sm:flex-row sm:items-center gap-2 text-sm text-muted-foreground">
                      <span>
                        {formatDateTime(selectedGrammarItem.createdAt)}
                      </span>
                      <span className="hidden sm:inline">•</span>
                      <span className="font-medium">
                        {languageLabel(selectedGrammarItem.detectedLanguage)}
                      </span>
                    </div>

                    <Separator />

                    <div>
                      <div className="flex items-center gap-2 mb-3">
                        {selectedGrammarItem.grammarErrors.length === 0 ? (
                          <>
                            <CheckCircle2 className="h-5 w-5 text-green-500" />
                            <h3 className="font-semibold text-base sm:text-lg">Không có lỗi nào</h3>
                          </>
                        ) : (
                          <>
                            <AlertCircle className="h-5 w-5 text-yellow-500" />
                            <h3 className="font-semibold text-base sm:text-lg">
                              Những chỗ chưa đúng ({selectedGrammarItem.grammarErrors.length})
                            </h3>
                          </>
                        )}
                      </div>

                      {selectedGrammarItem.grammarErrors.length === 0 ? (
                        <p className="text-muted-foreground">
                          Đoạn văn này không có lỗi ngữ pháp nào.
                        </p>
                      ) : (
                        <div className="space-y-3">
                          {selectedGrammarItem.grammarErrors.map((error) => (
                            <div
                              key={`${error.message}-${error.position.start}-${error.position.end}-${error.category}`}
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
                                  {selectedGrammarItem.originalText.slice(error.position.start, error.position.end)}
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

                    <div>
                      <h3 className="font-semibold text-base sm:text-lg mb-3">Văn bản đã sửa</h3>
                      <div className="p-3 sm:p-4 bg-muted rounded-lg">
                        <p className="whitespace-pre-wrap text-sm sm:text-base">{selectedGrammarItem.correctedText}</p>
                      </div>
                    </div>

                    <Separator />

                    <div>
                      <h3 className="font-semibold text-base sm:text-lg mb-3">Văn bản gốc</h3>
                      <div className="p-3 sm:p-4 bg-muted rounded-lg">
                        <p className="whitespace-pre-wrap text-sm sm:text-base">{selectedGrammarItem.originalText}</p>
                      </div>
                    </div>
                  </div>
                )}
              </DialogContent>
            </Dialog>
          )}

          {/* Translation Modal */}
          {selectedType === 'translation' && (
            <Dialog open={isDialogOpen} onOpenChange={handleDialogChange}>
              <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
                <DialogHeader>
                  <DialogTitle className="text-xl sm:text-2xl">
                    Chi tiết lần đối chiếu bản dịch
                  </DialogTitle>
                </DialogHeader>

                {selectedTranslationItem && (
                  <div className="space-y-4 sm:space-y-6">
                    <div className="flex flex-col sm:flex-row sm:items-center gap-2 text-sm text-muted-foreground">
                      <span>
                        {formatDateTime(selectedTranslationItem.createdAt)}
                      </span>
                    </div>

                    <Separator />

                    <div>
                      <h3 className="font-semibold text-base sm:text-lg mb-3">Ngôn ngữ nhận ra</h3>
                      <div className="space-y-2">
                        <p className="text-sm">
                          <span className="font-medium">Bản gốc: </span>
                          {formatLanguageName(selectedTranslationItem.detectedOriginalLanguage)}
                        </p>
                        <p className="text-sm">
                          <span className="font-medium">Bản dịch: </span>
                          {formatLanguageName(selectedTranslationItem.detectedTranslatedLanguage)}
                        </p>
                      </div>
                    </div>

                    <Separator />

                    <div>
                      <div className="flex items-center gap-2 mb-3">
                        {selectedTranslationItem.translationErrors.length === 0 ? (
                          <>
                            <CheckCircle2 className="h-5 w-5 text-green-500" />
                            <h3 className="font-semibold text-base sm:text-lg">Không có lỗi nào</h3>
                          </>
                        ) : (
                          <>
                            <AlertCircle className="h-5 w-5 text-yellow-500" />
                            <h3 className="font-semibold text-base sm:text-lg">
                              Những chỗ chưa đúng ({selectedTranslationItem.translationErrors.length})
                            </h3>
                          </>
                        )}
                      </div>

                      {selectedTranslationItem.translationErrors.length === 0 ? (
                        <p className="text-muted-foreground">
                          Bản dịch này không có lỗi nào.
                        </p>
                      ) : (
                        <div className="space-y-3">
                          {selectedTranslationItem.translationErrors.map((error) => (
                            <div
                              key={`${error.message}-${error.positions.original.join('-')}-${error.positions.translated.join('-')}`}
                              className="p-3 sm:p-4 border rounded-lg space-y-2"
                            >
                              <p className="font-medium text-sm sm:text-base">{error.message}</p>
                              <div className="text-sm text-muted-foreground">
                                {error.positions.original.length > 0 && (
                                  <p>
                                    <span className="font-medium">Vị trí trong bản gốc:</span>{' '}
                                    {error.positions.original.join(', ')}
                                  </p>
                                )}
                                {error.positions.translated.length > 0 && (
                                  <p>
                                    <span className="font-medium">Vị trí trong bản dịch:</span>{' '}
                                    {error.positions.translated.join(', ')}
                                  </p>
                                )}
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>

                    <Separator />

                    <div>
                      <h3 className="font-semibold text-base sm:text-lg mb-3">Văn bản gốc</h3>
                      <div className="p-3 sm:p-4 bg-muted rounded-lg">
                        <p className="whitespace-pre-wrap text-sm sm:text-base">{selectedTranslationItem.originalText}</p>
                      </div>
                    </div>

                    <Separator />

                    {selectedTranslationItem.translationErrors.length > 0 && selectedTranslationItem.correctedTranslation.trim() !== '' && (
                      <>
                        <div>
                          <h3 className="font-semibold text-base sm:text-lg mb-3">Bản dịch đã sửa</h3>
                          <div className="p-3 sm:p-4 bg-muted rounded-lg">
                            <p className="whitespace-pre-wrap text-sm sm:text-base">{selectedTranslationItem.correctedTranslation}</p>
                          </div>
                        </div>
                        <Separator />
                      </>
                    )}

                    <div>
                      <h3 className="font-semibold text-base sm:text-lg mb-3">Bản dịch của bạn</h3>
                      <div className="p-3 sm:p-4 bg-muted rounded-lg">
                        <p className="whitespace-pre-wrap text-sm sm:text-base">{selectedTranslationItem.translatedText}</p>
                      </div>
                    </div>
                  </div>
                )}
              </DialogContent>
            </Dialog>
          )}

          {/* Loading state */}
          {isLoading && (
            <div className="grid gap-4">
              {[...Array(5)].map((_, i) => (
                <Card key={i}>
                  <CardHeader>
                    <Skeleton className="h-6 w-3/4" />
                  </CardHeader>
                </Card>
              ))}
            </div>
          )}

          {/* Error state */}
          {isError && (
            <Card>
              <CardContent className="pt-6">
                <p className="text-center text-destructive">
                  Failed to load starred items
                </p>
              </CardContent>
            </Card>
          )}

          {/* Dictionary Starred List */}
          {selectedType === 'dictionary' && !isLoading && !isError && starredWords && (
            <>
              {starredWords.length === 0 ? (
                <Card>
                  <CardContent className="pt-6">
                    <p className="text-center text-muted-foreground">
                      Chưa lưu từ nào. Khi tra từ, bấm ngôi sao để giữ lại ở đây.
                    </p>
                  </CardContent>
                </Card>
              ) : (
                <div className="space-y-3">
                  {starredWords.map((item) => (
                    <Card
                      key={`${item.word.word}-${item.word.sourceLanguage}-${item.word.targetLanguage}`}
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
                          <div className="flex items-center gap-2 ml-4">
                            <div className="flex items-center gap-2 text-xs text-muted-foreground">
                              <span className="font-medium px-2 py-1 bg-muted rounded">
                                {getLanguageLabel(item.word.sourceLanguage)}
                              </span>
                              <span>→</span>
                              <span className="font-medium px-2 py-1 bg-muted rounded">
                                {getLanguageLabel(item.word.targetLanguage)}
                              </span>
                            </div>
                            <Button
                              variant="ghost"
                              size="icon"
                              onClick={(e) => handleUnstarWord(item, e)}
                              disabled={removingId === item.word.id}
                              className="h-8 w-8"
                              aria-label="Bỏ lưu từ này"
                            >
                              <Star className="h-5 w-5 fill-yellow-400 text-yellow-400" />
                            </Button>
                          </div>
                        </div>
                      </CardHeader>
                    </Card>
                  ))}
                </div>
              )}
            </>
          )}

          {/* Grammar Starred List */}
          {selectedType === 'grammar' && !isLoading && !isError && starredGrammarChecks && (
            <>
              {starredGrammarChecks.length === 0 ? (
                <Card>
                  <CardContent className="pt-6">
                    <p className="text-center text-muted-foreground">
                      Chưa lưu bài kiểm tra nào
                    </p>
                  </CardContent>
                </Card>
              ) : (
                <div className="space-y-3">
                  {starredGrammarChecks.map((item) => (
                    <Card
                      key={item.grammarCheck.id}
                      className="cursor-pointer hover:shadow-md transition-shadow"
                      onClick={() => handleGrammarClick(item)}
                    >
                      <CardHeader className="pb-3">
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex-1 min-w-0">
                            <CardTitle className="text-base sm:text-lg">
                              {truncateText(item.grammarCheck.originalText)}
                            </CardTitle>
                            <CardDescription className="text-sm mt-2">
                              {formatDateTime(item.starredAt)}
                            </CardDescription>
                          </div>
                          <div className="flex items-center gap-2">
                            <div className="flex flex-col items-end gap-2 text-xs">
                              <span className="font-medium px-2 py-1 bg-muted rounded whitespace-nowrap">
                                {languageLabel(item.grammarCheck.detectedLanguage)}
                              </span>
                              <span className={`inline-flex items-center rounded-md px-2 py-1 font-medium whitespace-nowrap ${
                                item.grammarCheck.grammarErrors.length === 0 
                                  ? 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-400' 
                                  : 'bg-yellow-50 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400'
                              }`}>
                                {item.grammarCheck.grammarErrors.length === 0 ? (
                                  <><CheckCircle2 className="h-3 w-3 mr-1" />Không lỗi</>
                                ) : (
                                  <>{item.grammarCheck.grammarErrors.length} lỗi</>
                                )}
                              </span>
                            </div>
                            <Button
                              variant="ghost"
                              size="icon"
                              onClick={(e) => handleUnstarGrammarCheck(item, e)}
                              disabled={removingId === item.grammarCheck.id}
                              className="h-8 w-8"
                              aria-label="Bỏ lưu bài kiểm tra này"
                            >
                              <Star className="h-5 w-5 fill-yellow-400 text-yellow-400" />
                            </Button>
                          </div>
                        </div>
                      </CardHeader>
                    </Card>
                  ))}
                </div>
              )}
            </>
          )}

          {/* Translation Starred List */}
          {selectedType === 'translation' && !isLoading && !isError && starredTranslationChecks && (
            <>
              {starredTranslationChecks.length === 0 ? (
                <Card>
                  <CardContent className="pt-6">
                    <p className="text-center text-muted-foreground">
                      Chưa lưu bản dịch nào
                    </p>
                  </CardContent>
                </Card>
              ) : (
                <div className="space-y-3">
                  {starredTranslationChecks.map((item) => (
                    <Card
                      key={item.translationCheck.id}
                      className="cursor-pointer hover:shadow-md transition-shadow"
                      onClick={() => handleTranslationClick(item)}
                    >
                      <CardHeader className="pb-3">
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex-1 min-w-0">
                            <CardTitle className="text-base sm:text-lg">
                              {truncateText(item.translationCheck.originalText)}
                            </CardTitle>
                            <CardDescription className="text-sm mt-2">
                              {formatDateTime(item.starredAt)}
                            </CardDescription>
                          </div>
                          <div className="flex items-center gap-2">
                            <div className="flex flex-col items-end gap-2 text-xs">
                              <div className="flex items-center gap-1">
                                <span className="font-medium px-2 py-1 bg-muted rounded whitespace-nowrap">
                                  {formatLanguageName(item.translationCheck.detectedOriginalLanguage)}
                                </span>
                                <Languages className="h-3 w-3" />
                                <span className="font-medium px-2 py-1 bg-muted rounded whitespace-nowrap">
                                  {formatLanguageName(item.translationCheck.detectedTranslatedLanguage)}
                                </span>
                              </div>
                              <span className={`inline-flex items-center rounded-md px-2 py-1 font-medium whitespace-nowrap ${
                                item.translationCheck.translationErrors.length === 0 
                                  ? 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-400' 
                                  : 'bg-yellow-50 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400'
                              }`}>
                                {item.translationCheck.translationErrors.length === 0 ? (
                                  <><CheckCircle2 className="h-3 w-3 mr-1" />Không lỗi</>
                                ) : (
                                  <>{item.translationCheck.translationErrors.length} lỗi</>
                                )}
                              </span>
                            </div>
                            <Button
                              variant="ghost"
                              size="icon"
                              onClick={(e) => handleUnstarTranslationCheck(item, e)}
                              disabled={removingId === item.translationCheck.id}
                              className="h-8 w-8"
                              aria-label="Bỏ lưu bản dịch này"
                            >
                              <Star className="h-5 w-5 fill-yellow-400 text-yellow-400" />
                            </Button>
                          </div>
                        </div>
                      </CardHeader>
                    </Card>
                  ))}
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </>
  )
}
