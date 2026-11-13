import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { toast } from 'sonner'
import { ArrowLeftRight, BookOpen, FileCheck, Gamepad2, TrendingUp } from 'lucide-react'
import { useQuery } from '@tanstack/react-query'
import type { GameCategory, GameStats } from '@practice/shared'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Checkbox } from '@/components/ui/checkbox'
import { Label } from '@/components/ui/label'
import { env } from '@/config/env'
import { Snowfall } from '@/components/Snowfall'

export const Route = createFileRoute('/_authenticated/game/')({
  component: GameHome,
})

function GameHome() {
  const navigate = useNavigate()
  const [selectedCategories, setSelectedCategories] = useState<Array<GameCategory>>(['dictionary', 'grammar', 'translation'])
  const [questionCount, setQuestionCount] = useState(10)
  const [starting, setStarting] = useState(false)

  // Fetch game stats
  const { data: stats, isLoading: statsLoading } = useQuery<GameStats>({
    queryKey: ['gameStats'],
    queryFn: async () => {
      const response = await fetch(`${env.VITE_API_URL}/api/game/stats`, {
        credentials: 'include',
      })

      if (!response.ok) {
        throw new Error('Không tải được thống kê')
      }

      return response.json()
    },
  })

  const handleCategoryToggle = (category: GameCategory) => {
    setSelectedCategories(prev =>
      prev.includes(category)
        ? prev.filter(c => c !== category)
        : [...prev, category]
    )
  }

  const handleStartGame = async () => {
    if (selectedCategories.length === 0) {
      toast.error('Chọn ít nhất một chủ đề')
      return
    }

    setStarting(true)

    try {
      const response = await fetch(`${env.VITE_API_URL}/api/game/start`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          categories: selectedCategories,
          questionCount,
        }),
      })

      if (!response.ok) {
        const data = await response.json().catch(() => ({}))
        throw new Error(data.message || 'Không bắt đầu được ván chơi')
      }

      const data = await response.json()
      
      // Navigate to play page with session ID and questions
      navigate({
        to: '/game/play',
        search: { 
          sessionId: data.sessionId,
          questions: JSON.stringify(data.questions),
        },
      })
    } catch (error: any) {
      toast.error(error.message || 'Không bắt đầu được ván chơi')
    } finally {
      setStarting(false)
    }
  }

  const accuracyPercentage =
    stats && stats.totalQuestionsAnswered > 0
      ? Math.round((stats.correctAnswers / stats.totalQuestionsAnswered) * 100)
      : 0

  return (
    <div className="min-h-screen bg-linear-to-br from-purple-50 via-white to-blue-50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900 relative">
      <Snowfall />
      
      <div className="container mx-auto px-4 py-8 max-w-6xl relative">
        <div className="text-center mb-8">
          <div className="flex items-center justify-center mb-4">
            <Gamepad2 className="h-12 w-12 text-purple-600 dark:text-purple-400" />
          </div>
          <h1 className="text-4xl font-bold mb-2 bg-clip-text text-transparent bg-linear-to-r from-purple-600 to-blue-600 dark:from-purple-400 dark:to-blue-400">
            Trò chơi ôn tập
          </h1>
          <p className="text-muted-foreground">
            Câu hỏi được lấy từ chính những gì bạn đã tra, đã kiểm tra
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          {/* Game Setup Card */}
          <Card>
            <CardHeader>
              <CardTitle>Bắt đầu ván mới</CardTitle>
              <CardDescription>Chọn chủ đề và số câu hỏi</CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* Category Selection */}
              <div className="space-y-4">
                <Label className="text-base font-semibold">Chủ đề</Label>
                <div className="space-y-3">
                  <div className="flex items-center space-x-3">
                    <Checkbox
                      id="dictionary"
                      checked={selectedCategories.includes('dictionary')}
                      onCheckedChange={() => handleCategoryToggle('dictionary')}
                    />
                    <Label htmlFor="dictionary" className="flex items-center gap-2 cursor-pointer">
                      <BookOpen className="h-4 w-4" />
                      Từ điển
                    </Label>
                  </div>
                  <div className="flex items-center space-x-3">
                    <Checkbox
                      id="grammar"
                      checked={selectedCategories.includes('grammar')}
                      onCheckedChange={() => handleCategoryToggle('grammar')}
                    />
                    <Label htmlFor="grammar" className="flex items-center gap-2 cursor-pointer">
                      <FileCheck className="h-4 w-4" />
                      Ngữ pháp
                    </Label>
                  </div>
                  <div className="flex items-center space-x-3">
                    <Checkbox
                      id="translation"
                      checked={selectedCategories.includes('translation')}
                      onCheckedChange={() => handleCategoryToggle('translation')}
                    />
                    <Label htmlFor="translation" className="flex items-center gap-2 cursor-pointer">
                      <ArrowLeftRight className="h-4 w-4" />
                      Bản dịch
                    </Label>
                  </div>
                </div>
              </div>

              {/* Question Count */}
              <div className="space-y-3">
                <Label className="text-base font-semibold">Số câu hỏi</Label>
                <div className="grid grid-cols-4 gap-2">
                  {[5, 10, 15, 20].map(count => (
                    <Button
                      key={count}
                      variant={questionCount === count ? 'default' : 'outline'}
                      onClick={() => setQuestionCount(count)}
                    >
                      {count}
                    </Button>
                  ))}
                </div>
              </div>

              <Button
                onClick={handleStartGame}
                disabled={starting || selectedCategories.length === 0}
                className="w-full"
                size="lg"
              >
                {starting ? 'Đang mở ván...' : 'Bắt đầu'}
              </Button>
            </CardContent>
          </Card>

          {/* Stats Card */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <TrendingUp className="h-5 w-5" />
                Kết quả của bạn
              </CardTitle>
              <CardDescription>Tổng hợp từ tất cả các ván đã chơi</CardDescription>
            </CardHeader>
            <CardContent>
              {statsLoading ? (
                <div className="text-center py-8 text-muted-foreground">Đang tải...</div>
              ) : stats && stats.totalGamesPlayed > 0 ? (
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="text-center p-4 bg-muted rounded-lg">
                      <div className="text-2xl font-bold">{stats.totalGamesPlayed}</div>
                      <div className="text-sm text-muted-foreground">Ván đã chơi</div>
                    </div>
                    <div className="text-center p-4 bg-muted rounded-lg">
                      <div className="text-2xl font-bold">{accuracyPercentage}%</div>
                      <div className="text-sm text-muted-foreground">Tỷ lệ đúng</div>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <h4 className="font-semibold text-sm">Theo chủ đề</h4>
                    <div className="space-y-2">
                      <div className="flex justify-between items-center">
                        <span className="text-sm">Từ điển</span>
                        <span className="text-sm font-medium">
                          {stats.byCategory.dictionary.total > 0
                            ? `${Math.round((stats.byCategory.dictionary.correct / stats.byCategory.dictionary.total) * 100)}%`
                            : '0%'}
                        </span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-sm">Ngữ pháp</span>
                        <span className="text-sm font-medium">
                          {stats.byCategory.grammar.total > 0
                            ? `${Math.round((stats.byCategory.grammar.correct / stats.byCategory.grammar.total) * 100)}%`
                            : '0%'}
                        </span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-sm">Bản dịch</span>
                        <span className="text-sm font-medium">
                          {stats.byCategory.translation.total > 0
                            ? `${Math.round((stats.byCategory.translation.correct / stats.byCategory.translation.total) * 100)}%`
                            : '0%'}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  Chưa chơi ván nào. Bắt đầu ván đầu tiên đi.
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
