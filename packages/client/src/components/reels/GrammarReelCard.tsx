import { Card } from '@/components/ui/card'
import { Separator } from '@/components/ui/separator'
import { FileCheck, CheckCircle2, AlertCircle } from 'lucide-react'
import type { GrammarCheckResult } from '@/types/history'
import { errorCategoryLabel, formatDateTime, languageLabel } from '@/lib/labels'

type GrammarReelCardProps = {
  data: GrammarCheckResult
}

export function GrammarReelCard({ data }: GrammarReelCardProps) {
  const hasErrors = data.grammarErrors.length > 0

  return (
    <div className="w-full h-full flex items-center justify-center p-4">
      <Card className="w-full max-w-2xl max-h-[90vh] overflow-y-auto bg-gradient-to-br from-green-50 to-emerald-50 dark:from-green-950/30 dark:to-emerald-950/30 border-2 border-green-200 dark:border-green-800">
        <div className="p-6 space-y-6">
          {/* Type indicator */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-green-600 dark:text-green-400">
              <FileCheck className="h-5 w-5" />
              <span className="text-sm font-medium">Kiểm tra ngữ pháp</span>
            </div>
            <span className="text-xs font-medium px-2 py-1 bg-background rounded">
              {languageLabel(data.detectedLanguage)}
            </span>
          </div>

          {/* Status */}
          <div className="text-center space-y-2">
            {hasErrors ? (
              <>
                <AlertCircle className="h-12 w-12 text-yellow-500 mx-auto" />
                <p className="text-xl font-semibold text-yellow-700 dark:text-yellow-400">
                  Có {data.grammarErrors.length} lỗi
                </p>
              </>
            ) : (
              <>
                <CheckCircle2 className="h-12 w-12 text-green-500 mx-auto" />
                <p className="text-xl font-semibold text-green-700 dark:text-green-400">
                  Không có lỗi nào
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

          {/* Corrected Text (if there are errors) */}
          {hasErrors && (
            <>
              <div>
                <h3 className="font-semibold text-sm text-muted-foreground mb-2">
                  Văn bản đã sửa
                </h3>
                <div className="p-4 bg-green-50 dark:bg-green-950/20 rounded-lg border border-green-200 dark:border-green-800">
                  <p className="whitespace-pre-wrap text-sm">{data.correctedText}</p>
                </div>
              </div>

              <Separator />

              {/* Grammar Errors */}
              <div>
                <h3 className="font-semibold text-sm text-muted-foreground mb-3">
                  Những chỗ chưa đúng
                </h3>
                <div className="space-y-3">
                  {data.grammarErrors.map((error, idx) => (
                    <div
                      key={`${error.message}-${error.position.start}-${error.position.end}-${idx}`}
                      className="p-3 border rounded-lg bg-background space-y-2"
                    >
                      <div className="flex items-start justify-between gap-2">
                        <p className="font-medium text-sm">{error.message}</p>
                        <span className="px-2 py-1 text-xs rounded-full bg-secondary whitespace-nowrap">
                          {errorCategoryLabel(error.category)}
                        </span>
                      </div>
                      <div className="flex flex-wrap items-center gap-2 text-xs">
                        <span className="px-2 py-0.5 rounded bg-red-500/10 text-red-700 dark:text-red-400 line-through decoration-red-500/60">
                          {data.originalText.slice(error.position.start, error.position.end)}
                        </span>
                        <span className="text-muted-foreground">→</span>
                        <span className="px-2 py-0.5 rounded bg-green-500/10 text-green-700 dark:text-green-400 font-medium">
                          {error.suggestion}
                        </span>
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
