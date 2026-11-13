import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useCallback, useEffect, useState } from 'react'
import { DICTIONARY_SOURCE_LANGUAGES, DICTIONARY_TARGET_LANGUAGE, LANGUAGE } from '@practice/shared'
import { toast } from 'sonner'
import { ArrowRight, MoreVertical, Share, Star, Volume2 } from 'lucide-react'
import type {Language, Word} from '@practice/shared';
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Separator } from '@/components/ui/separator'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { addRecentSearch } from '@/components/CommandPalette'
import { normalizeString } from '@/lib/utils'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { env } from '@/config/env'
import { Snowfall } from '@/components/Snowfall'
import { Reindeer } from '@/components/Reindeer'

type SearchParams = {
  sourceLanguage?: Language
  targetLanguage?: Language
  word?: string
}

export const Route = createFileRoute('/_authenticated/dictionary/')({
  validateSearch: (search: Record<string, unknown>): SearchParams => {
    return {
      // Un lien partagé peut porter n'importe quoi. On le ramène sur un couple
      // servi plutôt que de laisser l'API répondre 400 sur une URL d'archive.
      sourceLanguage: (DICTIONARY_SOURCE_LANGUAGES as readonly string[])
        .includes(search.sourceLanguage as string)
        ? (search.sourceLanguage as Language)
        : LANGUAGE.FRENCH,
      targetLanguage: DICTIONARY_TARGET_LANGUAGE,
      word: typeof search.word === 'string' ? search.word : undefined,
    }
  },
  component: DictionarySearch,
})

function DictionarySearch() {

  const navigate = useNavigate()
  const { sourceLanguage, targetLanguage, word } = Route.useSearch()
  const [searchWord, setSearchWord] = useState(word || '')
  const [result, setResult] = useState<Word | null>(null)
  const [loading, setLoading] = useState(false)
  const [isStarred, setIsStarred] = useState(false)
  const [togglingStarStatus, setTogglingStarStatus] = useState(false)
  // Le lexique est fini : un mot peut ne pas y être. C'est une réponse, pas une
  // panne, et elle mérite mieux qu'un toast rouge.
  const [notFound, setNotFound] = useState<{ word: string, suggestions: string[] } | null>(null)

  // La garde « les deux langues sont identiques » a disparu avec le choix de
  // la cible : elle appelait navigate() pendant le rendu, ce que React interdit.

  const performSearch = useCallback(async (wordToSearch: string) => {
    const normalizedWord = normalizeString(wordToSearch)
    
    if (!normalizedWord) {
      toast.error('Bạn chưa nhập từ nào')
      return
    }

    setLoading(true)
    setResult(null)
    setNotFound(null)

    try {
      const response = await fetch(`${env.VITE_API_URL}/api/dictionary/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          searchingWord: normalizedWord,
          sourceLanguage,
          targetLanguage,
        }),
      })

      if (response.status === 404) {
        const body = await response.json() as { searchingWord: string, suggestions: string[] }
        setNotFound({ word: body.searchingWord, suggestions: body.suggestions ?? [] })
        return
      }

      if (!response.ok) {
        throw new Error('Không tra được từ này. Vui lòng thử lại.')
      }

      const data: Word = await response.json()
      setResult(data)
      
      // Check if word is starred
      checkStarStatus(data.id)
      
      // Add to recent searches
      addRecentSearch(normalizedWord, sourceLanguage!, targetLanguage!)
      
      // Clear the search input after successful search
      setSearchWord('')
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra khi tra từ'
      toast.error(errorMessage)
    } finally {
      setLoading(false)
    }
  }, [sourceLanguage, targetLanguage])

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault()
    
    const normalizedWord = normalizeString(searchWord)
    
    if (!normalizedWord) {
      toast.error('Bạn chưa nhập từ nào')
      return
    }

    // Update URL with word parameter - useEffect will handle the search
    navigate({
      to: '/dictionary',
      search: { sourceLanguage, targetLanguage, word: normalizedWord }
    })
  }

  const checkStarStatus = async (wordId: string) => {
    try {
      const response = await fetch(
        `${env.VITE_API_URL}/api/dictionary/starred/check?wordId=${wordId}`,
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
      // Silent fail for star status check
      console.error('Failed to check star status:', err)
    }
  }

  const toggleStar = async () => {
    if (!result) return

    setTogglingStarStatus(true)

    try {
      const response = await fetch(`${env.VITE_API_URL}/api/dictionary/starred/toggle`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          wordId: result.id,
        }),
      })

      if (!response.ok) {
        throw new Error('Không lưu được')
      }

      const data = await response.json()
      setIsStarred(data.starred)
      toast.success(data.starred ? 'Đã lưu từ này' : 'Đã bỏ lưu từ này')
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    } finally {
      setTogglingStarStatus(false)
    }
  }

  const handleShare = async () => {
    // Validate required data is available
    if (!result) {
      toast.error('Chưa có kết quả nào để chia sẻ')
      return
    }
    
    if (!sourceLanguage || !targetLanguage) {
      toast.error('Không tạo được liên kết chia sẻ')
      return
    }

    try {
      // Build URL using URLSearchParams for proper encoding
      const params = new URLSearchParams({
        sourceLanguage,
        targetLanguage,
        word: result.word
      })
      const url = `${window.location.origin}/dictionary?${params.toString()}`
      
      await navigator.clipboard.writeText(url)
      toast.success('Đã sao chép liên kết')
    } catch (err) {
      console.error('Share failed:', err)
      toast.error('Không sao chép được liên kết. Bạn thử lại, hoặc chép thẳng từ thanh địa chỉ.')
    }
  }

  const handleSpeak = () => {
    if (!result) {
      toast.error('Chưa có từ nào để nghe')
      return
    }

    if (!sourceLanguage) {
      toast.error('Không xác định được ngôn ngữ')
      return
    }

    // Map language codes to YouGlish language names
    const languageMap: Record<Language, string> = {
      [LANGUAGE.ENGLISH]: 'english',
      [LANGUAGE.FRENCH]: 'french',
      [LANGUAGE.VIETNAMESE]: 'vietnamese',
      [LANGUAGE.SPANISH]: 'spanish',
      [LANGUAGE.GERMAN]: 'german',
    }

    const youglishLanguage = languageMap[sourceLanguage]
    const url = `https://youglish.com/pronounce/${encodeURIComponent(result.word)}/${youglishLanguage}`
    
    window.open(url, '_blank')
  }

  // Auto-search when word parameter is present in URL
  useEffect(() => {
    if (word && word.trim()) {
      performSearch(word)
    }
  }, [word, performSearch])

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

  return (
    <>
      <div className="aurora-background">
        <div className="aurora-layer"></div>
      </div>
      <Snowfall />
      {/* Les rennes s'effacent dès qu'il y a quelque chose à lire. Ils sont en
          position fixe par-dessus la page, à 65 % et 75 % de la hauteur : c'est
          exactement là où tombe la carte d'un mot un peu long. Une décoration
          qui bouge à côté d'un mot qu'on essaie de lire est un concurrent. */}
      {!result && !notFound && <Reindeer />}
      <div className="container mx-auto max-w-4xl pt-24 sm:pt-52 px-4">
        <div className="space-y-8 sm:space-y-12">
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-3">
          <div className="flex items-center gap-2 sm:gap-3 w-full sm:w-auto justify-center">
            {/* Deux langues source, une cible. Le sélecteur offrait les cinq et
                un bouton d'échange : depuis que la recherche lit un lexique
                compilé, « vietnamese → french » n'a pas de données derrière lui
                et l'API le refuse. Un menu qui propose ce que le serveur rejette
                est un piège, pas une fonctionnalité. */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button className="text-3xl sm:text-5xl font-bold tracking-tight text-primary hover:scale-105 transition-transform cursor-pointer underline decoration-2 decoration-primary/30 underline-offset-4 sm:underline-offset-8 hover:decoration-primary/60">
                  {getLanguageLabel(sourceLanguage!)}
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="start" className="w-48">
                {DICTIONARY_SOURCE_LANGUAGES.map((lang) => (
                  <DropdownMenuItem
                    key={lang}
                    onClick={() => navigate({
                      to: '/dictionary',
                      search: { sourceLanguage: lang, targetLanguage: DICTIONARY_TARGET_LANGUAGE },
                    })}
                    className={sourceLanguage === lang ? 'bg-accent' : ''}
                  >
                    {getLanguageLabel(lang)}
                  </DropdownMenuItem>
                ))}
              </DropdownMenuContent>
            </DropdownMenu>

            <ArrowRight className="h-6 w-6 sm:h-9 sm:w-9 text-muted-foreground shrink-0" />

            {/* La cible ne se choisit pas : il n'y en a qu'une. Un menu à une
                entrée fait croire qu'il y en aura d'autres. */}
            <span className="text-3xl sm:text-5xl font-bold tracking-tight text-primary">
              {getLanguageLabel(DICTIONARY_TARGET_LANGUAGE)}
            </span>
          </div>
        </div>

        <form onSubmit={handleSearch} className="flex justify-center px-2 sm:px-4">
          <div className="relative w-full max-w-3xl">
            <Input
              id="search-word"
              type="text"
              placeholder="Tra một từ..."
              value={searchWord}
              onChange={(e) => setSearchWord(e.target.value)}
              className="pr-20 sm:pr-28 h-12 sm:h-16 text-base sm:text-lg rounded-full shadow-lg border-2 focus-visible:ring-2 px-4 sm:px-6"
              disabled={loading}
              autoCapitalize="none"
            />
            <Button 
              type="submit" 
              disabled={loading || !searchWord.trim()}
              className="absolute right-1 sm:right-2 top-1/2 -translate-y-1/2 rounded-full h-10 sm:h-12 px-4 sm:px-6 text-sm sm:text-base"
            >
              {loading ? 'Đang tra...' : 'Tra từ'}
            </Button>
          </div>
        </form>

        {!loading && notFound && (
          <div className="flex justify-center px-2 sm:px-0">
            <Card className="w-full max-w-2xl">
              <CardHeader>
                <CardTitle className="text-xl">
                  Không tìm thấy « {notFound.word} »
                </CardTitle>
              </CardHeader>
              {notFound.suggestions.length > 0 && (
                <>
                  <Separator />
                  <CardContent>
                    <p className="text-sm text-muted-foreground mb-3">Có phải bạn muốn tìm:</p>
                    <div className="flex flex-wrap gap-2">
                      {notFound.suggestions.map((suggestion) => (
                        <Button
                          key={suggestion}
                          variant="outline"
                          size="sm"
                          onClick={() => navigate({
                            to: '/dictionary',
                            search: { sourceLanguage, targetLanguage, word: suggestion },
                          })}
                        >
                          {suggestion}
                        </Button>
                      ))}
                    </div>
                  </CardContent>
                </>
              )}
            </Card>
          </div>
        )}

        {!loading && result && (
          <div className="flex justify-center px-2 sm:px-0">
            <Card className="w-full max-w-2xl">
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <CardTitle className="text-2xl sm:text-3xl">{result.word}</CardTitle>
                    {result.ipa && result.ipa.length > 0 && (
                      <p className="text-sm text-muted-foreground mt-1">{result.ipa.join('  ')}</p>
                    )}
                    {/* Vous avez tapé « allions », la page est celle d'« aller ».
                        Sans cette ligne, le titre a l'air de ne pas répondre. */}
                    {result.matchedForm && result.matchedForm !== result.word && (
                      <p className="text-sm text-muted-foreground mt-1">
                        « {result.matchedForm} » →{' '}
                        <span className="font-medium text-foreground">{result.word}</span>
                      </p>
                    )}
                    {/* Affiché aussi quand la recherche a tapé juste : « went » a
                        sa propre entrée, dont la glose entière est « quá khứ của
                        go ». Sans ce renvoi on repart sans le sens. */}
                    {result.alsoFrom && result.alsoFrom.length > 0 && (
                      <p className="text-sm text-muted-foreground mt-1">
                        Cũng là dạng của{' '}
                        {result.alsoFrom.map((other, i) => (
                          <span key={other}>
                            {i > 0 && ', '}
                            <button
                              type="button"
                              className="underline underline-offset-2 hover:text-foreground"
                              onClick={() => navigate({
                                to: '/dictionary',
                                search: { sourceLanguage, targetLanguage, word: other },
                              })}
                            >
                              {other}
                            </button>
                          </span>
                        ))}
                      </p>
                    )}
                    <CardDescription className="text-lg sm:text-xl mt-2">
                      {result.translated}
                    </CardDescription>
                  </div>
                  <div className="flex items-center gap-1">
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={toggleStar}
                      disabled={togglingStarStatus}
                      aria-label={isStarred ? 'Bỏ lưu từ này' : 'Lưu từ này'}
                    >
                      <Star
                        className={`h-6 w-6 ${isStarred ? 'fill-yellow-400 text-yellow-400' : 'text-muted-foreground'}`}
                      />
                    </Button>
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button
                          variant="ghost"
                          size="icon"
                          aria-label="Thêm lựa chọn"
                        >
                          <MoreVertical className="h-6 w-6 text-muted-foreground" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem onClick={handleSpeak}>
                          <Volume2 className="mr-2 h-4 w-4" />
                          Nghe phát âm
                        </DropdownMenuItem>
                        <DropdownMenuItem onClick={handleShare}>
                          <Share className="mr-2 h-4 w-4" />
                          Chia sẻ
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                </div>
              </CardHeader>
              <Separator />
              <CardContent className="space-y-4 sm:space-y-6">
                {result.explains.map((explainItem, idx) => (
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
                        <h4 className="font-semibold text-sm text-muted-foreground">Ví dụ</h4>
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
                    
                    {idx < result.explains.length - 1 && <Separator />}
                  </div>
                ))}
              </CardContent>
              {result.wiki && (
                <>
                  <Separator />
                  <CardFooter className="pt-4">
                    {/* Le dictionnaire est compilé : quand une glose a l'air
                        fausse, il n'y a rien à interroger. Ce lien rouvre
                        l'article d'où elle vient. */}
                    <a
                      href={result.wiki}
                      target="_blank"
                      rel="noreferrer noopener"
                      className="text-sm text-muted-foreground hover:text-foreground underline underline-offset-2"
                    >
                      Kiểm tra trên vi.wiktionary
                    </a>
                  </CardFooter>
                </>
              )}
            </Card>
          </div>
        )}
      </div>
    </div>
    </>
  )
}
