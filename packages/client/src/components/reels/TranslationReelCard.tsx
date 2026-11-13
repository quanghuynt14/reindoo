import { Card } from '@/components/ui/card'
import { Separator } from '@/components/ui/separator'
import { Languages, CheckCircle2, AlertCircle } from 'lucide-react'
import type { TranslateCheckResult } from '@/types/history'
import { formatDateTime, languageLabel } from '@/lib/labels'

type TranslationReelCardProps = {
  data: TranslateCheckResult
}

const formatLanguageName = (language: string) => {
  const label = languageLabel(language)
  return label.charAt(0).toUpperCase() + label.slice(1)
}

export function TranslationReelCard({ data }: TranslationReelCardProps) {
  const hasErrors = data.translationErrors.length > 0
  const hasCorrectedTranslation = data.correctedTranslation && data.correctedTranslation.trim() !== ''

  return (
    <div className="w-full h-full flex items-center justify-center p-4">
      <Card className="w-full max-w-2xl max-h-[90vh] overflow-y-auto bg-gradient-to-br from-purple-50 to-pink-50 dark:from-purple-950/30 dark:to-pink-950/30 border-2 border-purple-200 dark:border-purple-800">
        <div className="p-6 space-y-6">
          {/* Type indicator */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-purple-600 dark:text-purple-400">
              <Languages className="h-5 w-5" />
              <span className="text-sm font-medium">Đối chiếu bản dịch</span>
            </div>
            <div className="flex items-center gap-1 text-xs">
              <span className="font-medium px-2 py-1 bg-background rounded">
                {formatLanguageName(data.detectedOriginalLanguage)}
              </span>
              <span>→</span>
              <span className="font-medium px-2 py-1 bg-background rounded">
                {formatLanguageName(data.detectedTranslatedLanguage)}
              </span>
            </div>
          </div>

          {/* Status */}
          <div className="text-center space-y-2">
            {hasErrors ? (
              <>
                <AlertCircle className="h-12 w-12 text-yellow-500 mx-auto" />
                <p className="text-xl font-semibold text-yellow-700 dark:text-yellow-400">
                  Có {data.translationErrors.length} lỗi
                </p>
              </>
            ) : (
              <>
                <CheckCircle2 className="h-12 w-12 text-green-500 mx-auto" />
                <p className="text-xl font-semibold text-green-700 dark:text-green-400">
                  Bản dịch chuẩn
                </p>
              </>
            )}
          </div>

          <Separator />

          {/* Original Text */}
          <div>
            <h3 className="font-semibold text-sm text-muted-foreground mb-2">Văn bản gốc</h3>
            <div className="p-4 bg-background rounded-lg border">
              <p className="whitespace-pre-wrap text-sm">{data.originalText}</p>
            </div>
          </div>

          {/* Your Translation */}
          <div>
            <h3 className="font-semibold text-sm text-muted-foreground mb-2">
              Bản dịch của bạn
            </h3>
            <div className="p-4 bg-background rounded-lg border">
              <p className="whitespace-pre-wrap text-sm">{data.translatedText}</p>
            </div>
          </div>

          {/* Corrected Translation (if there are errors and correction exists) */}
          {hasErrors && hasCorrectedTranslation && (
            <>
              <div>
                <h3 className="font-semibold text-sm text-muted-foreground mb-2">
                  Bản dịch đã sửa
                </h3>
                <div className="p-4 bg-green-50 dark:bg-green-950/20 rounded-lg border border-green-200 dark:border-green-800">
                  <p className="whitespace-pre-wrap text-sm">{data.correctedTranslation}</p>
                </div>
              </div>

              <Separator />

              {/* Translation Errors */}
              <div>
                <h3 className="font-semibold text-sm text-muted-foreground mb-3">
                  Những chỗ chưa đúng
                </h3>
                <div className="space-y-3">
                  {data.translationErrors.map((error, idx) => (
                    <div
                      key={`${error.message}-${error.positions.original.join('-')}-${idx}`}
                      className="p-3 border rounded-lg bg-background space-y-2"
                    >
                      <p className="font-medium text-sm">{error.message}</p>
                      <div className="text-xs text-muted-foreground space-y-1">
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
              </div>
            </>
          )}

          {/* Timestamp */}
          <div className="text-center text-xs text-muted-foreground pt-4">
            {formatDateTime(data.createdAt)}
          </div>
        </div>
      </Card>
    </div>
  )
}
