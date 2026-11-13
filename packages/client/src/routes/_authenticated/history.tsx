import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { LANGUAGE   } from '@practice/shared'
import { AlertCircle, CheckCircle2, Clock, Languages, MoreVertical, Trash2 } from 'lucide-react'
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
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Button } from '@/components/ui/button'
import { env } from '@/config/env'
import { Skeleton } from '@/components/ui/skeleton'
import { Snowfall } from '@/components/Snowfall'
import { Separator } from '@/components/ui/separator'
import { errorCategoryLabel, formatDateTime, languageLabel } from '@/lib/labels'

type HistoryType = 'dictionary' | 'grammar' | 'translation'

// Query parameters for history fetch
const HISTORY_PAGE = 1;
const HISTORY_LIMIT = 20;
const HISTORY_SORT_BY = 'createdAt';
const HISTORY_SORT_ORDER = 'desc' as const;
const TRUNCATE_TEXT_LENGTH = 100;

type DictionaryHistoryItem = {
  id: string
  userId: string
  word: Word
  searchedAt: string
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

const fetchDictionaryHistory = async (): Promise<Array<DictionaryHistoryItem>> => {
  const response = await fetch(`${env.VITE_API_URL}/api/dictionary/history`, {
    method: 'GET',
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error('Không tải được lịch sử tra từ')
  }

  const data = await response.json()
  return data.searchHistory
}

const fetchGrammarHistory = async (): Promise<Array<GrammarCheckResult>> => {
  const response = await fetch(
    `${env.VITE_API_URL}/api/grammar-check/history?page=${HISTORY_PAGE}&limit=${HISTORY_LIMIT}&sortBy=${HISTORY_SORT_BY}&sortOrder=${HISTORY_SORT_ORDER}`,
    {
      method: 'GET',
      credentials: 'include',
    }
  )

  if (!response.ok) {
    throw new Error('Không tải được lịch sử kiểm tra ngữ pháp')
  }

  const data = await response.json()
  return data.results
}

const fetchTranslationHistory = async (): Promise<Array<TranslateCheckResult>> => {
  const response = await fetch(
    `${env.VITE_API_URL}/api/translate-check/history?page=${HISTORY_PAGE}&limit=${HISTORY_LIMIT}&sortBy=${HISTORY_SORT_BY}&sortOrder=${HISTORY_SORT_ORDER}`,
    {
      method: 'GET',
      credentials: 'include',
    }
  )

  if (!response.ok) {
    throw new Error('Không tải được lịch sử đối chiếu bản dịch')
  }

  const data = await response.json()
  return data.results
}

export const Route = createFileRoute('/_authenticated/history')({
  component: CentralizedHistory,
})

const formatLanguageName = (language: string) => {
  const label = languageLabel(language)
  return label.charAt(0).toUpperCase() + label.slice(1)
}

function CentralizedHistory() {
  const [selectedType, setSelectedType] = useState<HistoryType>('dictionary')
  const [selectedDictionaryItem, setSelectedDictionaryItem] = useState<DictionaryHistoryItem | null>(null)
  const [selectedGrammarItem, setSelectedGrammarItem] = useState<GrammarCheckResult | null>(null)
  const [selectedTranslationItem, setSelectedTranslationItem] = useState<TranslateCheckResult | null>(null)
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [isDeleting, setIsDeleting] = useState(false)

  const queryClient = useQueryClient()

  const { data: dictionaryHistory, isLoading: isDictionaryLoading, isError: isDictionaryError } = useQuery({
    queryKey: ['dictionary-history'],
    queryFn: fetchDictionaryHistory,
    enabled: selectedType === 'dictionary',
  })

  const { data: grammarHistory, isLoading: isGrammarLoading, isError: isGrammarError } = useQuery({
    queryKey: ['grammar-history'],
    queryFn: fetchGrammarHistory,
    enabled: selectedType === 'grammar',
  })

  const { data: translationHistory, isLoading: isTranslationLoading, isError: isTranslationError } = useQuery({
    queryKey: ['translation-history'],
    queryFn: fetchTranslationHistory,
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

  const handleDictionaryClick = (item: DictionaryHistoryItem) => {
    setSelectedDictionaryItem(item)
    setIsDialogOpen(true)
  }

  const handleGrammarClick = (item: GrammarCheckResult) => {
    setSelectedGrammarItem(item)
    setIsDialogOpen(true)
  }

  const handleTranslationClick = (item: TranslateCheckResult) => {
    setSelectedTranslationItem(item)
    setIsDialogOpen(true)
  }

  const truncateText = (text: string, maxLength: number = TRUNCATE_TEXT_LENGTH) => {
    if (text.length <= maxLength) return text
    return text.substring(0, maxLength) + '...'
  }

  const handleDeleteDictionary = async (historyId: string) => {
    if (isDeleting) return

    setIsDeleting(true)
    try {
      const response = await fetch(`${env.VITE_API_URL}/api/dictionary/history/${historyId}`, {
        method: 'DELETE',
        credentials: 'include',
      })

      if (!response.ok) {
        throw new Error('Không xoá được mục này')
      }

      toast.success('Đã xoá khỏi lịch sử')
      setIsDialogOpen(false)
      setSelectedDictionaryItem(null)
      queryClient.invalidateQueries({ queryKey: ['dictionary-history'] })
    } catch (error) {
      console.error('Error deleting history:', error)
      toast.error('Không xoá được mục này')
    } finally {
      setIsDeleting(false)
    }
  }

  const handleDeleteGrammar = async (historyId: string) => {
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
      setSelectedGrammarItem(null)
      queryClient.invalidateQueries({ queryKey: ['grammar-history'] })
    } catch (error) {
      console.error('Error deleting history:', error)
      toast.error('Không xoá được mục này')
    } finally {
      setIsDeleting(false)
    }
  }

  const handleDeleteTranslation = async (historyId: string) => {
    if (isDeleting) return

    setIsDeleting(true)
    try {
      const response = await fetch(`${env.VITE_API_URL}/api/translate-check/history/${historyId}`, {
        method: 'DELETE',
        credentials: 'include',
      })

      if (!response.ok) {
        throw new Error('Không xoá được mục này')
      }

      toast.success('Đã xoá khỏi lịch sử')
      setIsDialogOpen(false)
      setSelectedTranslationItem(null)
      queryClient.invalidateQueries({ queryKey: ['translation-history'] })
    } catch (error) {
      console.error('Error deleting history:', error)
      toast.error('Không xoá được mục này')
    } finally {
      setIsDeleting(false)
    }
  }

  const isLoading = selectedType === 'dictionary' ? isDictionaryLoading : selectedType === 'grammar' ? isGrammarLoading : isTranslationLoading
  const isError = selectedType === 'dictionary' ? isDictionaryError : selectedType === 'grammar' ? isGrammarError : isTranslationError

  return (
    <>
      <div className="aurora-background">
        <div className="aurora-layer"></div>
      </div>
      <Snowfall />
      <div className="container mx-auto max-w-4xl pt-24 px-4">
        <div className="space-y-6">
          <div className="flex items-center gap-3">
            <Clock className="h-8 w-8 text-primary" />
            <h1 className="text-3xl font-bold tracking-tight">Lịch sử</h1>
          </div>

          {/* Filter Buttons */}
          <Card>
            <CardContent>
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
            <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
              <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
                <DialogHeader>
                  <div className="flex items-center justify-between">
                    <DialogTitle className="text-2xl sm:text-3xl">
                      {selectedDictionaryItem?.word.word || 'Đang tải...'}
                    </DialogTitle>
                    {selectedDictionaryItem && (
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon" disabled={isDeleting}>
                            <MoreVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem
                            variant="destructive"
                            onClick={() => handleDeleteDictionary(selectedDictionaryItem.id)}
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

                {selectedDictionaryItem && (
                  <div className="space-y-4 sm:space-y-6">
                    <div>
                      <p className="text-lg sm:text-xl text-muted-foreground">
                        {selectedDictionaryItem.word.translated}
                      </p>
                    </div>

                    <Separator />

                    {selectedDictionaryItem.word.explains.map((explainItem, idx) => (
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

                        {idx < selectedDictionaryItem.word.explains.length - 1 && <Separator />}
                      </div>
                    ))}
                  </div>
                )}
              </DialogContent>
            </Dialog>
          )}

          {/* Grammar Modal */}
          {selectedType === 'grammar' && (
            <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
              <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
                <DialogHeader>
                  <div className="flex items-center justify-between">
                    <DialogTitle className="text-xl sm:text-2xl">
                      Chi tiết lần kiểm tra ngữ pháp
                    </DialogTitle>
                    {selectedGrammarItem && (
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon" disabled={isDeleting}>
                            <MoreVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem
                            variant="destructive"
                            onClick={() => handleDeleteGrammar(selectedGrammarItem.id)}
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
            <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
              <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
                <DialogHeader>
                  <div className="flex items-center justify-between">
                    <DialogTitle className="text-xl sm:text-2xl">
                      Chi tiết lần đối chiếu bản dịch
                    </DialogTitle>
                    {selectedTranslationItem && (
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon" disabled={isDeleting}>
                            <MoreVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem
                            variant="destructive"
                            onClick={() => handleDeleteTranslation(selectedTranslationItem.id)}
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
                  Không tải được lịch sử
                </p>
              </CardContent>
            </Card>
          )}

          {/* Dictionary History List */}
          {selectedType === 'dictionary' && !isLoading && !isError && dictionaryHistory && (
            <>
              {dictionaryHistory.length === 0 ? (
                <Card>
                  <CardContent className="pt-6">
                    <p className="text-center text-muted-foreground">
                      Chưa có lịch sử nào. Cứ tra vài từ, chúng sẽ được lưu lại ở đây.
                    </p>
                  </CardContent>
                </Card>
              ) : (
                <div className="space-y-3">
                  {dictionaryHistory.map((item) => (
                    <Card
                      key={`${item.word.word}-${item.word.translated}-${item.word.sourceLanguage}-${item.word.targetLanguage}`}
                      className="cursor-pointer hover:shadow-md transition-shadow"
                      onClick={() => handleDictionaryClick(item)}
                    >
                      <CardHeader>
                        <div className="flex items-start justify-between">
                          <div className="flex-1">
                            <CardTitle className="text-xl">{item.word.word}</CardTitle>
                            <CardDescription className="text-base mt-1">
                              {item.word.translated}
                            </CardDescription>
                            <CardDescription className="text-sm mt-2">
                              {formatDateTime(item.searchedAt)}
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
                </div>
              )}
            </>
          )}

          {/* Grammar History List */}
          {selectedType === 'grammar' && !isLoading && !isError && grammarHistory && (
            <>
              {grammarHistory.length === 0 ? (
                <Card>
                  <CardContent className="pt-6">
                    <p className="text-center text-muted-foreground">
                      Chưa có lần kiểm tra nào
                    </p>
                  </CardContent>
                </Card>
              ) : (
                <div className="space-y-3">
                  {grammarHistory.map((check) => (
                    <Card
                      key={check.id}
                      className="cursor-pointer hover:shadow-md transition-shadow"
                      onClick={() => handleGrammarClick(check)}
                    >
                      <CardHeader className="pb-3">
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex-1 min-w-0">
                            <CardTitle className="text-base sm:text-lg">
                              {truncateText(check.originalText)}
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
              )}
            </>
          )}

          {/* Translation History List */}
          {selectedType === 'translation' && !isLoading && !isError && translationHistory && (
            <>
              {translationHistory.length === 0 ? (
                <Card>
                  <CardContent className="pt-6">
                    <p className="text-center text-muted-foreground">
                      Chưa có lần đối chiếu nào
                    </p>
                  </CardContent>
                </Card>
              ) : (
                <div className="space-y-3">
                  {translationHistory.map((check) => (
                    <Card
                      key={check.id}
                      className="cursor-pointer hover:shadow-md transition-shadow"
                      onClick={() => handleTranslationClick(check)}
                    >
                      <CardHeader className="pb-3">
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex-1 min-w-0">
                            <CardTitle className="text-base sm:text-lg">
                              {truncateText(check.originalText)}
                            </CardTitle>
                            <CardDescription className="text-sm mt-2">
                              {formatDateTime(check.createdAt)}
                            </CardDescription>
                          </div>
                          <div className="flex flex-col items-end gap-2 text-xs">
                            <div className="flex items-center gap-1">
                              <span className="font-medium px-2 py-1 bg-muted rounded whitespace-nowrap">
                                {formatLanguageName(check.detectedOriginalLanguage)}
                              </span>
                              <Languages className="h-3 w-3" />
                              <span className="font-medium px-2 py-1 bg-muted rounded whitespace-nowrap">
                                {formatLanguageName(check.detectedTranslatedLanguage)}
                              </span>
                            </div>
                            <span className={`inline-flex items-center rounded-md px-2 py-1 font-medium whitespace-nowrap ${
                              check.translationErrors.length === 0 
                                ? 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-400' 
                                : 'bg-yellow-50 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400'
                            }`}>
                              {check.translationErrors.length === 0 ? (
                                <><CheckCircle2 className="h-3 w-3 mr-1" />Không lỗi</>
                              ) : (
                                <>{check.translationErrors.length} lỗi</>
                              )}
                            </span>
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
