import { createFileRoute } from '@tanstack/react-router'
import { Clock } from 'lucide-react'
import { Snowfall } from '@/components/Snowfall'
import { InfiniteScrollHistoryList } from '@/components/dictionary/InfiniteScrollHistoryList'

export const Route = createFileRoute('/_authenticated/dictionary/history')({
  component: DictionaryHistory,
})

function DictionaryHistory() {
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
            <h1 className="text-3xl font-bold tracking-tight">Lịch sử tra từ</h1>
          </div>

          <InfiniteScrollHistoryList />
        </div>
      </div>
    </>
  )
}

