import { useCallback, useState } from 'react'
import { Volume2 } from 'lucide-react'

import type { DictionaryHistoryItem } from '@/types/history'
import { Separator } from '@/components/ui/separator'
import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from '@/components/ui/drawer'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { Switch } from '@/components/ui/switch'

type DictionaryReelCardProps = {
  data: DictionaryHistoryItem
  isVeiled: boolean
  onToggleVeil: () => void
  onToggleRevealMode: () => void
  isDesktop: boolean
  onDetailsOpenChange?: (open: boolean) => void
  perCardReveal?: boolean
}

function DetailsBody({ data }: { data: DictionaryHistoryItem }) {
  return (
    <div className="flex flex-col gap-4 sm:gap-6">
      <div>
        <p className="text-lg sm:text-xl text-muted-foreground">
          {data.word.translated}
        </p>
      </div>

      <Separator />

      {data.word.explains.map((explainItem, idx) => (
        <div
          key={`${explainItem.explain}-${idx}`}
          className="flex flex-col gap-3"
        >
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
            <div className="flex flex-col gap-3">
              <h3 className="font-semibold text-sm text-muted-foreground">
                Ví dụ
              </h3>
              {explainItem.exampleSentences.map((example, exampleIdx) => (
                <div
                  key={`${example.sourceSentence}-${example.targetTranslation}-${exampleIdx}`}
                >
                  <div className="border-l-4 border-primary pl-4 py-2 bg-background rounded-r">
                    <p className="font-medium">{example.sourceSentence}</p>
                    <p className="text-muted-foreground mt-1">
                      {example.targetTranslation}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          )}

          {idx < data.word.explains.length - 1 && <Separator />}
        </div>
      ))}
    </div>
  )
}

export function DictionaryReelCard({
  data,
  isVeiled: parentIsVeiled,
  onToggleVeil: parentToggleVeil,
  onToggleRevealMode,
  isDesktop,
  onDetailsOpenChange,
  perCardReveal = false,
}: DictionaryReelCardProps) {
  const [detailsOpen, setDetailsOpen] = useState(false)
  const [localIsVeiled, setLocalIsVeiled] = useState(true)
  const localToggleVeil = useCallback(() => setLocalIsVeiled((v) => !v), [])

  // Use local state when per-card reveal is enabled, otherwise use parent's global state
  const isVeiled = perCardReveal ? localIsVeiled : parentIsVeiled
  const onToggleVeil = perCardReveal ? localToggleVeil : parentToggleVeil

  const handleDetailsOpenChange = useCallback(
    (open: boolean) => {
      setDetailsOpen(open)
      onDetailsOpenChange?.(open)
    },
    [onDetailsOpenChange]
  )

  const handleSpeak = useCallback(() => {
    const url = `https://youglish.com/pronounce/${encodeURIComponent(data.word.word)}/${data.word.sourceLanguage}`
    window.open(url, '_blank')
  }, [data.word.word, data.word.sourceLanguage])

  const cardContent = (topTrigger: React.ReactNode) => (
    <div className="w-full max-w-2xl h-[420px] overflow-hidden rounded-xl border-2 shadow-sm bg-gradient-to-br from-blue-50 to-indigo-50 dark:from-blue-950/30 dark:to-indigo-950/30 border-blue-200 dark:border-blue-800 grid grid-rows-2">
      {/* Top half: clickable to open details */}
      {topTrigger}

      {/* Bottom half: clickable reveal zone — flush to left, right, bottom */}
      <button
        type="button"
        onClick={onToggleVeil}
        aria-label={isVeiled ? 'Hiện nghĩa' : 'Ẩn nghĩa'}
        aria-expanded={!isVeiled}
        className={[
          'border-t px-6 cursor-pointer',
          'flex items-center justify-center',
          'transition-all duration-150 ease-in-out',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2',
          isVeiled
            ? 'bg-sky-100/80 dark:bg-sky-950/30 border-sky-300/50 dark:border-sky-700/50'
            : 'bg-sky-50/60 dark:bg-sky-900/40 border-sky-200 dark:border-sky-600',
        ].join(' ')}
      >
          <p
            className={[
              `${translatedFontSize} font-medium text-foreground text-center`,
              'transition-opacity duration-150 ease-in-out',
              isVeiled ? 'opacity-0 select-none' : 'opacity-100',
            ].join(' ')}
          >
            {data.word.translated}
          </p>
        </button>
    </div>
  )

  const wordFontSize = (() => {
    if (isDesktop) return 'text-5xl'
    const longest = Math.max(...data.word.word.split(/\s+/).map(w => w.length))
    return longest > 16 ? 'text-3xl' : longest > 12 ? 'text-4xl' : 'text-5xl'
  })()

  const translatedFontSize = (() => {
    if (isDesktop) return 'text-2xl'
    const longest = Math.max(...data.word.translated.split(/\s+/).map(w => w.length))
    return longest > 16 ? 'text-lg' : longest > 12 ? 'text-xl' : 'text-2xl'
  })()

  const topHalf = (
    <div className="flex flex-col items-center justify-center gap-4 px-6 cursor-pointer transition-colors hover:bg-blue-100/50 dark:hover:bg-blue-900/20">
      <h2 className={`${wordFontSize} font-bold text-foreground text-center`}>
        {data.word.word}
      </h2>
    </div>
  )

  return (
    <div className="w-full h-full flex items-center justify-center p-4">
      {/* Details panel — Dialog on desktop, Drawer on mobile */}
      <div className="flex w-full max-w-2xl flex-col items-start gap-3">
        {isDesktop ? (
          <Dialog open={detailsOpen} onOpenChange={handleDetailsOpenChange}>
            {cardContent(
              <DialogTrigger asChild>{topHalf}</DialogTrigger>
            )}
            <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
              <DialogHeader>
                <div className="flex items-center justify-between">
                  <DialogTitle className="text-2xl sm:text-3xl">
                    {data.word.word}
                  </DialogTitle>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={handleSpeak}
                    aria-label="Nghe phát âm"
                  >
                    <Volume2 className="h-5 w-5" />
                  </Button>
                </div>
              </DialogHeader>
              <DetailsBody data={data} />
            </DialogContent>
          </Dialog>
        ) : (
          <Drawer open={detailsOpen} onOpenChange={handleDetailsOpenChange}>
            {cardContent(
              <DrawerTrigger asChild>{topHalf}</DrawerTrigger>
            )}
            <DrawerContent>
              <DrawerHeader>
                <div className="flex items-center justify-between">
                  <DrawerTitle className="text-2xl">
                    {data.word.word}
                  </DrawerTitle>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={handleSpeak}
                    aria-label="Nghe phát âm"
                  >
                    <Volume2 className="h-5 w-5" />
                  </Button>
                </div>
              </DrawerHeader>
              <div className="flex-1 min-h-0 overflow-y-auto px-4 pb-6">
                <DetailsBody data={data} />
              </div>
            </DrawerContent>
          </Drawer>
        )}

        <div className="flex items-center rounded-full border border-border/60 bg-background/80 px-2 py-1 shadow-sm backdrop-blur-sm">
          <Switch
            aria-label="Bật/tắt chế độ che nghĩa"
            checked={perCardReveal}
            onCheckedChange={onToggleRevealMode}
            size="sm"
          />
        </div>
      </div>
    </div>
  )
}
