import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { Home, RotateCcw, Trophy } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Snowfall } from '@/components/Snowfall'

type SearchParams = {
  sessionId: string
  score: number
  total: number
}

export const Route = createFileRoute('/_authenticated/game/results')({
  validateSearch: (search: Record<string, unknown>): SearchParams => {
    return {
      sessionId: (search.sessionId as string) || '',
      score: Number(search.score) || 0,
      total: Number(search.total) || 0,
    }
  },
  component: GameResults,
})

function GameResults() {
  const navigate = useNavigate()
  const { score, total } = Route.useSearch()

  const percentage = total > 0 ? Math.round((score / total) * 100) : 0

  const getPerformanceMessage = () => {
    if (percentage >= 90) return 'Xuất sắc! 🌟'
    if (percentage >= 75) return 'Làm tốt lắm! 🎉'
    if (percentage >= 60) return 'Khá đấy! 👍'
    if (percentage >= 50) return 'Cứ luyện tiếp! 💪'
    return 'Đừng nản, làm lại nào! 📚'
  }

  const getPerformanceColor = () => {
    if (percentage >= 75) return "text-green-600 dark:text-green-400"
    if (percentage >= 50) return "text-yellow-600 dark:text-yellow-400"
    return "text-red-600 dark:text-red-400"
  }

  return (
    <div className="min-h-screen bg-linear-to-br from-purple-50 via-white to-blue-50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900 relative">
      <Snowfall />
      
      <div className="container mx-auto px-4 py-8 max-w-2xl relative">
        <div className="text-center mb-8">
          <div className="flex items-center justify-center mb-4">
            <Trophy className="h-20 w-20 text-yellow-500" />
          </div>
          <h1 className="text-4xl font-bold mb-2">
            {getPerformanceMessage()}
          </h1>
          <p className="text-muted-foreground">
            Bạn đã chơi xong ván này
          </p>
        </div>

        <Card className="mb-6">
          <CardHeader>
            <CardTitle>Điểm của bạn</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-center space-y-4">
              <div className={`text-6xl font-bold ${getPerformanceColor()}`}>
                {score}/{total}
              </div>
              <div className="text-2xl font-semibold text-muted-foreground">
                Đúng {percentage}%
              </div>
              <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-4 mt-4">
                <div
                  className={`h-4 rounded-full transition-all duration-500 ${
                    percentage >= 75
                      ? 'bg-green-600'
                      : percentage >= 50
                      ? 'bg-yellow-600'
                      : 'bg-red-600'
                  }`}
                  style={{ width: `${percentage}%` }}
                />
              </div>
            </div>
          </CardContent>
        </Card>

        <div className="grid grid-cols-2 gap-4">
          <Button
            onClick={() => navigate({ to: '/game' })}
            variant="outline"
            size="lg"
            className="w-full"
          >
            <Home className="mr-2 h-5 w-5" />
            Về trang trò chơi
          </Button>
          <Button
            onClick={() => navigate({ to: '/game' })}
            size="lg"
            className="w-full"
          >
            <RotateCcw className="mr-2 h-5 w-5" />
            Chơi ván nữa
          </Button>
        </div>
      </div>
    </div>
  )
}
