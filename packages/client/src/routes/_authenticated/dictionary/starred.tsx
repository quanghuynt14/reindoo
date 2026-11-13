import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { LANGUAGE   } from '@practice/shared'
import { toast } from 'sonner'
import { Star } from 'lucide-react'
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
import { env } from '@/config/env'
import { Skeleton } from '@/components/ui/skeleton'
import { Separator } from '@/components/ui/separator'
import { Button } from '@/components/ui/button'
import { Snowfall } from '@/components/Snowfall'

type StarredWordItem = {
  userId: string
  word: Word
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

export const Route = createFileRoute('/_authenticated/dictionary/starred')({
  component: DictionaryStarred,
  loader: async () => {
    try {
      const starredWords = await fetchStarredWords()
      return { starredWords }
    } catch (error) {
      console.error('Failed to load starred words:', error)
      return { starredWords: [] }
    }
  },
  pendingComponent: () => (
    <div className="container mx-auto max-w-4xl pt-24 px-4">
      <div className="space-y-6">
        <div className="flex items-center gap-3">
          <Star className="h-8 w-8 text-primary" />
          <h1 className="text-3xl font-bold tracking-tight">Từ đã lưu</h1>
        </div>
        <div className="grid gap-4">
          {[...Array(5)].map((_, i) => (
            <Card key={i}>
              <CardHeader>
                <Skeleton className="h-6 w-3/4" />
              </CardHeader>
            </Card>
          ))}
        </div>
      </div>
    </div>
  ),
})

function DictionaryStarred() {
  const { starredWords: initialStarredWords } = Route.useLoaderData()
  const [starredWords, setStarredWords] = useState<Array<StarredWordItem>>(initialStarredWords)
  const [selectedWord, setSelectedWord] = useState<StarredWordItem | null>(null)
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [removingWord, setRemovingWord] = useState<string | null>(null)

  const refetchStarredWords = async () => {
    try {
      const response = await fetch(`${env.VITE_API_URL}/api/dictionary/starred`, {
        method: 'GET',
        credentials: 'include',
      })

      if (!response.ok) {
        throw new Error('Không tải được danh sách từ đã lưu')
      }

      const data = await response.json()
      setStarredWords(data.starredWords)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    }
  }

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
    setSelectedWord(item)
    setIsDialogOpen(true)
  }

  const handleUnstar = async (wordItem: StarredWordItem, event: React.MouseEvent) => {
    event.stopPropagation()
    
    setRemovingWord(`${wordItem.word.word}-${wordItem.word.sourceLanguage}-${wordItem.word.targetLanguage}`)

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
        throw new Error('Không bỏ lưu được')
      }

      toast.success('Đã bỏ lưu từ này')
      // Refresh the list
      await refetchStarredWords()
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    } finally {
      setRemovingWord(null)
    }
  }

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
          <h1 className="text-3xl font-bold tracking-tight">Từ đã lưu</h1>
        </div>

        <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
          <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle className="text-2xl sm:text-3xl">
                {selectedWord?.word.word || 'Đang tải...'}
              </DialogTitle>
            </DialogHeader>
            
            {selectedWord && (
              <div className="space-y-4 sm:space-y-6">
                <div>
                  <p className="text-lg sm:text-xl text-muted-foreground">
                    {selectedWord.word.translated}
                  </p>
                </div>
                
                <Separator />
                
                {selectedWord.word.explains.map((explainItem, idx) => (
                  <div key={idx} className="space-y-3">
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
                    
                    {idx < selectedWord.word.explains.length - 1 && <Separator />}
                  </div>
                ))}
              </div>
            )}
          </DialogContent>
        </Dialog>

        {starredWords.length === 0 ? (
          <Card>
            <CardContent className="pt-6">
              <p className="text-center text-muted-foreground">
                Chưa có từ nào được lưu. Khi tra từ, bấm ngôi sao để giữ lại ở đây.
              </p>
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-3">
            {starredWords.map((item, index) => (
              <Card
                key={index}
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
                        onClick={(e) => handleUnstar(item, e)}
                        aria-label="Bỏ lưu từ này"
                        disabled={removingWord === `${item.word.word}-${item.word.sourceLanguage}-${item.word.targetLanguage}`}
                        className="h-8 w-8"
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
      </div>
    </div>
    </>
  )
}
