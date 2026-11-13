import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { toast } from 'sonner'
import { CheckCircle2, XCircle } from 'lucide-react'
import type { GameQuestion } from '@practice/shared'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { env } from '@/config/env'
import { Snowfall } from '@/components/Snowfall'
import { cn } from '@/lib/utils'
import { gameCategoryLabel, questionTypeLabel } from '@/lib/labels'

type SearchParams = {
  sessionId: string
  questions?: string // JSON stringified questions array
}

export const Route = createFileRoute('/_authenticated/game/play')({
  validateSearch: (search: Record<string, unknown>): SearchParams => {
    if (!search.sessionId || typeof search.sessionId !== 'string') {
      throw new Error('Thiếu mã phiên chơi')
    }
    return {
      sessionId: search.sessionId,
      questions: search.questions as string,
    }
  },
  component: GamePlay,
})

type AnswerState = {
  questionId: string
  selectedIndex: number
  correct: boolean
  correctAnswerIndex: number
  explanation?: string
}

function GamePlay() {
  const navigate = useNavigate()
  const { sessionId, questions: questionsParam } = Route.useSearch()
  
  let questions: Array<GameQuestion> = []
  try {
    questions = questionsParam ? JSON.parse(questionsParam) : []
  } catch (error) {
    toast.error('Không tải được câu hỏi')
    setTimeout(() => {
      navigate({ to: '/game' })
    }, 0)
    return null
  }
  
  const [currentIndex, setCurrentIndex] = useState(0)
  const [answers, setAnswers] = useState<Map<string, AnswerState>>(new Map())
  const [submitting, setSubmitting] = useState(false)
  const [showResult, setShowResult] = useState(false)

  const currentQuestion = questions.at(currentIndex)
  const currentAnswer = currentQuestion ? answers.get(currentQuestion.id) : null

  if (!currentQuestion) {
    return (
      <div className="min-h-screen bg-linear-to-br from-purple-50 via-white to-blue-50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900 flex items-center justify-center">
        <Card className="max-w-md w-full mx-4">
          <CardHeader>
            <CardTitle>Không có câu hỏi nào</CardTitle>
            <CardDescription>Hãy quay lại và mở một ván mới.</CardDescription>
          </CardHeader>
          <CardContent className="flex justify-end">
            <Button onClick={() => navigate({ to: '/game' })}>Về trang trò chơi</Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  const handleAnswerSelect = async (selectedIndex: number) => {
    if (currentAnswer || submitting) return

    setSubmitting(true)

    try {
      const response = await fetch(`${env.VITE_API_URL}/api/game/answer`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          sessionId,
          questionId: currentQuestion.id,
          selectedAnswerIndex: selectedIndex,
        }),
      })

      if (!response.ok) {
        throw new Error('Không gửi được câu trả lời')
      }

      const data = await response.json()
      
      setAnswers(prev => new Map(prev).set(currentQuestion.id, {
        questionId: currentQuestion.id,
        selectedIndex,
        correct: data.correct,
        correctAnswerIndex: data.correctAnswerIndex,
        explanation: data.explanation,
      }))
      
      setShowResult(true)
    } catch (error: any) {
      toast.error(error.message || 'Không gửi được câu trả lời')
    } finally {
      setSubmitting(false)
    }
  }

  const handleNext = () => {
    if (currentIndex < questions.length - 1) {
      setCurrentIndex(prev => prev + 1)
      setShowResult(false)
    } else {
      // Navigate to results page
      navigate({ 
        to: '/game/results', 
        search: { 
          sessionId,
          score: Array.from(answers.values()).filter(a => a.correct).length,
          total: questions.length,
        } 
      })
    }
  }

  const correctAnswers = Array.from(answers.values()).filter(a => a.correct).length

  return (
    <div className="min-h-screen bg-linear-to-br from-purple-50 via-white to-blue-50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900 relative">
      <Snowfall />
      
      <div className="container mx-auto px-4 py-8 max-w-3xl relative">
        {/* Progress Header */}
        <div className="mb-6">
          <div className="flex justify-between items-center mb-2">
            <span className="text-sm font-medium">
              Câu {currentIndex + 1} / {questions.length}
            </span>
            <span className="text-sm font-medium">
              Đúng: {correctAnswers}/{answers.size}
            </span>
          </div>
          <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
            <div
              className="bg-purple-600 h-2 rounded-full transition-all duration-300"
              style={{ width: `${((currentIndex + 1) / questions.length) * 100}%` }}
            />
          </div>
        </div>

        {/* Question Card */}
        <Card className="mb-6">
          <CardHeader>
            <div className="flex items-center gap-2 mb-2">
              <span className="px-2 py-1 rounded-full text-xs font-medium bg-purple-100 dark:bg-purple-900 text-purple-700 dark:text-purple-300">
                {gameCategoryLabel(currentQuestion.category)}
              </span>
              <span className="px-2 py-1 rounded-full text-xs font-medium bg-blue-100 dark:bg-blue-900 text-blue-700 dark:text-blue-300">
                {questionTypeLabel(currentQuestion.type)}
              </span>
            </div>
            <CardTitle className="text-xl">{currentQuestion.question}</CardTitle>
            {currentQuestion.context && (
              <CardDescription className="mt-2 text-base">
                <div className="p-3 bg-muted rounded-md whitespace-pre-wrap">
                  {currentQuestion.context}
                </div>
              </CardDescription>
            )}
          </CardHeader>
          <CardContent className="space-y-3">
            {currentQuestion.options.map((option, index) => {
              const isSelected = currentAnswer?.selectedIndex === index
              const isCorrect = currentAnswer?.correctAnswerIndex === index
              const showCorrect = showResult && isCorrect
              const showIncorrect = showResult && isSelected && !isCorrect

              return (
                <Button
                  key={index}
                  variant="outline"
                  className={cn(
                    "w-full justify-start text-left h-auto py-3 px-3 sm:px-4 text-sm sm:text-base whitespace-normal wrap-break-word",
                    showCorrect && "border-green-500 bg-green-50 dark:bg-green-950",
                    showIncorrect && "border-red-500 bg-red-50 dark:bg-red-950",
                    !showResult && "hover:bg-accent"
                  )}
                  disabled={!!currentAnswer || submitting}
                  onClick={() => handleAnswerSelect(index)}
                >
                  <span className="flex-1 min-w-0">{option}</span>
                  {showCorrect && <CheckCircle2 className="h-5 w-5 text-green-600 shrink-0" />}
                  {showIncorrect && <XCircle className="h-5 w-5 text-red-600 shrink-0" />}
                </Button>
              )
            })}
          </CardContent>
        </Card>

        {/* Result Feedback */}
        {showResult && currentAnswer && (
          <Card className={cn(
            "mb-6",
            currentAnswer.correct ? "border-green-500" : "border-red-500"
          )}>
            <CardContent className="pt-6">
              <div className="flex items-start gap-3">
                {currentAnswer.correct ? (
                  <CheckCircle2 className="h-6 w-6 text-green-600 shrink-0 mt-0.5" />
                ) : (
                  <XCircle className="h-6 w-6 text-red-600 shrink-0 mt-0.5" />
                )}
                <div className="flex-1">
                  <h3 className={cn(
                    "font-semibold mb-1",
                    currentAnswer.correct ? "text-green-600" : "text-red-600"
                  )}>
                    {currentAnswer.correct ? 'Đúng rồi!' : 'Chưa đúng'}
                  </h3>
                  {!currentAnswer.correct && (
                    <p className="text-sm text-muted-foreground mb-2">
                      Đáp án đúng là: <strong>{currentQuestion.options[currentAnswer.correctAnswerIndex]}</strong>
                    </p>
                  )}
                  {currentAnswer.explanation && (
                    <p className="text-sm text-muted-foreground">
                      {currentAnswer.explanation}
                    </p>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Navigation */}
        {showResult && (
          <div className="flex justify-center">
            <Button onClick={handleNext} size="lg">
              {currentIndex < questions.length - 1 ? 'Câu tiếp theo' : 'Xem kết quả'}
            </Button>
          </div>
        )}
      </div>
    </div>
  )
}
