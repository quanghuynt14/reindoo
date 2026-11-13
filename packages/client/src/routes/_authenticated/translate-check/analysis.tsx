import { Link, createFileRoute } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import { toast } from 'sonner'
import {
  AlertCircle,
  ArrowLeft,
  BookOpen,
  CheckCircle2,
  Lightbulb,
  Loader2,
  Minus,
  Target,
  TrendingDown,
  TrendingUp,
} from 'lucide-react'
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { env } from '@/config/env'
import { errorCategoryLabel, priorityLabel, trendLabel } from '@/lib/labels'

export const Route = createFileRoute('/_authenticated/translate-check/analysis')({
  component: AnalysisPage,
})

type ErrorPattern = {
  category: string
  count: number
  percentage: number
  examples: Array<{
    message: string
    textSnippet: string
  }>
  trend: 'improving' | 'stable' | 'worsening'
}

type ImprovementArea = {
  category: string
  errorCount: number
  priority: 'high' | 'medium' | 'low'
  recommendation: string
  resources: Array<string>
}

type AnalysisData = {
  errorPatterns: Array<ErrorPattern>
  improvementAreas: Array<ImprovementArea>
  progressMetrics: {
    totalChecks: number
    totalErrors: number
    averageErrorsPerCheck: number
    improvementRate: number
    recentTrend: 'improving' | 'stable' | 'worsening'
  }
  categoryBreakdown: Array<{
    category: string
    count: number
    percentage: number
  }>
  timeBasedAnalysis: {
    last7Days: { checks: number; errors: number; avgErrors: number }
    previous7Days: { checks: number; errors: number; avgErrors: number }
    improvement: number
  }
}

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8', '#82CA9D']

const TrendIcon = ({ trend }: { trend: 'improving' | 'stable' | 'worsening' }) => {
  if (trend === 'improving') {
    return <TrendingUp className="h-4 w-4 text-green-500" />
  }
  if (trend === 'worsening') {
    return <TrendingDown className="h-4 w-4 text-red-500" />
  }
  return <Minus className="h-4 w-4 text-gray-500" />
}

const PriorityBadge = ({ priority }: { priority: 'high' | 'medium' | 'low' }) => {
  const colors = {
    high: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
    medium: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
    low: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
  }

  return (
    <span className={`px-2 py-1 text-xs rounded-full font-medium ${colors[priority]}`}>
      {priorityLabel(priority)}
    </span>
  )
}

function AnalysisPage() {
  const [analysis, setAnalysis] = useState<AnalysisData | null>(null)
  const [loading, setLoading] = useState(true)

  const fetchAnalysis = async () => {
    setLoading(true)
    try {
      const response = await fetch(`${env.VITE_API_URL}/api/translate-check/analysis`, {
        method: 'GET',
        credentials: 'include',
      })

      if (!response.ok) {
        throw new Error('Không tải được số liệu')
      }

      const data = await response.json()
      setAnalysis(data)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Có lỗi xảy ra'
      toast.error(errorMessage)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchAnalysis()
  }, [])

  if (loading) {
    return (
      <div className="container mx-auto px-4 py-8 max-w-7xl">
        <div className="flex items-center justify-center min-h-[400px]">
          <Loader2 className="h-8 w-8 animate-spin" />
        </div>
      </div>
    )
  }

  if (!analysis) {
    return (
      <div className="container mx-auto px-4 py-8 max-w-7xl">
        <div className="text-center py-12">
          <AlertCircle className="h-16 w-16 text-muted-foreground mx-auto mb-4" />
          <p className="text-muted-foreground">Không tải được số liệu</p>
          <Button onClick={fetchAnalysis} className="mt-4">
            Thử lại
          </Button>
        </div>
      </div>
    )
  }

  if (analysis.progressMetrics.totalChecks === 0) {
    return (
      <div className="container mx-auto px-4 py-8 max-w-7xl">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
          <div className="flex items-center gap-3">
            <Target className="h-6 w-6 sm:h-8 sm:w-8" />
            <h1 className="text-2xl sm:text-3xl font-bold">Thống kê bản dịch</h1>
          </div>
          <Link to="/translate-check">
            <Button variant="outline" size="sm">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Về trang đối chiếu
            </Button>
          </Link>
        </div>
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <BookOpen className="h-16 w-16 text-muted-foreground mb-4" />
            <h3 className="text-xl font-semibold mb-2">Chưa có dữ liệu</h3>
            <p className="text-muted-foreground text-center mb-4">
              Đối chiếu vài bản dịch, rồi quay lại đây xem mình hay sai ở đâu
            </p>
            <Link to="/translate-check">
              <Button>Đi đối chiếu bản dịch</Button>
            </Link>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
        <div className="flex items-center gap-3">
          <Target className="h-6 w-6 sm:h-8 sm:w-8" />
          <h1 className="text-2xl sm:text-3xl font-bold">Thống kê bản dịch</h1>
        </div>
        <Link to="/translate-check">
          <Button variant="outline" size="sm">
            <ArrowLeft className="mr-2 h-4 w-4" />
            <span className="hidden sm:inline">Về trang đối chiếu</span>
            <span className="sm:hidden">Quay lại</span>
          </Button>
        </Link>
      </div>

      {/* Progress Overview */}
      <div className="grid gap-4 grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 mb-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-xs sm:text-sm font-medium">Số lần đối chiếu</CardTitle>
            <CheckCircle2 className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-xl sm:text-2xl font-bold">{analysis.progressMetrics.totalChecks}</div>
            <p className="text-xs text-muted-foreground">Tổng số lần đã đối chiếu</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-xs sm:text-sm font-medium">Tổng số lỗi</CardTitle>
            <AlertCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-xl sm:text-2xl font-bold">{analysis.progressMetrics.totalErrors}</div>
            <p className="text-xs text-muted-foreground">Lỗi đã tìm thấy</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-xs sm:text-sm font-medium">Lỗi trung bình</CardTitle>
            <Target className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-xl sm:text-2xl font-bold">
              {analysis.progressMetrics.averageErrorsPerCheck}
            </div>
            <p className="text-xs text-muted-foreground">Mỗi lần đối chiếu</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-xs sm:text-sm font-medium">Tiến bộ</CardTitle>
            <TrendIcon trend={analysis.progressMetrics.recentTrend} />
          </CardHeader>
          <CardContent>
            <div className="text-xl sm:text-2xl font-bold">
              {analysis.progressMetrics.improvementRate > 0 ? '+' : ''}
              {analysis.progressMetrics.improvementRate}%
            </div>
            <p className="text-xs text-muted-foreground">{trendLabel(analysis.progressMetrics.recentTrend)}</p>
          </CardContent>
        </Card>
      </div>

      {/* Improvement Areas */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle className="text-lg sm:text-xl flex items-center gap-2">
            <Lightbulb className="h-5 w-5" />
            Nên tập trung vào đâu
          </CardTitle>
          <CardDescription>Những mảng sửa được nhanh nhất, xếp theo mức ưu tiên</CardDescription>
        </CardHeader>
        <CardContent>
          {analysis.improvementAreas.length > 0 ? (
            <div className="space-y-4">
              {analysis.improvementAreas.map((area, index) => (
                <Card key={index} className="border">
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between gap-3 mb-3">
                      <div className="flex-1">
                        <h4 className="text-base sm:text-lg font-semibold mb-1">{errorCategoryLabel(area.category)}</h4>
                        <p className="text-xs sm:text-sm text-muted-foreground">
                          {area.errorCount} lỗi
                        </p>
                      </div>
                      <PriorityBadge priority={area.priority} />
                    </div>
                    <div className="space-y-3">
                      <div>
                        <h5 className="text-sm font-medium mb-1">Lời khuyên</h5>
                        <p className="text-xs sm:text-sm text-muted-foreground">{area.recommendation}</p>
                      </div>
                      <div>
                        <h5 className="text-sm font-medium mb-2">Cách luyện</h5>
                        <ul className="space-y-1">
                          {area.resources.map((resource, idx) => (
                            <li key={idx} className="flex items-start gap-2 text-xs sm:text-sm text-muted-foreground">
                              <span className="text-primary mt-1">•</span>
                              <span>{resource}</span>
                            </li>
                          ))}
                        </ul>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          ) : (
            <div className="text-center py-8 text-muted-foreground">
              <CheckCircle2 className="h-12 w-12 mx-auto mb-2 text-green-500" />
              <p>Không có mảng nào đáng ngại. Cứ giữ nhịp này.</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Error Patterns */}
      <div className="grid gap-6 lg:grid-cols-2 mb-6">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg sm:text-xl">Lỗi theo từng loại</CardTitle>
            <CardDescription>Chi tiết từng loại lỗi bạn hay mắc</CardDescription>
          </CardHeader>
          <CardContent>
            {analysis.errorPatterns.length > 0 ? (
              <div className="space-y-4">
                {analysis.errorPatterns.map((pattern, index) => (
                  <div key={index} className="border rounded-lg p-3 sm:p-4">
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <h4 className="text-sm sm:text-base font-semibold">{errorCategoryLabel(pattern.category)}</h4>
                        <TrendIcon trend={pattern.trend} />
                      </div>
                      <div className="text-right">
                        <div className="text-sm sm:text-base font-bold">{pattern.count}</div>
                        <div className="text-xs text-muted-foreground">{pattern.percentage.toFixed(1)}%</div>
                      </div>
                    </div>
                    {pattern.examples.length > 0 && (
                      <div className="mt-3 pt-3 border-t">
                        <h5 className="text-xs font-medium mb-2">Ví dụ</h5>
                        <div className="space-y-2">
                          {pattern.examples.slice(0, 2).map((example, idx) => (
                            <div key={idx} className="text-xs bg-muted p-2 rounded">
                              <p className="font-medium text-foreground mb-1">{example.message}</p>
                              <p className="text-muted-foreground italic truncate">&quot;{example.textSnippet}&quot;</p>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-muted-foreground text-sm">Chưa đủ dữ liệu để thống kê</div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg sm:text-xl">Tỷ trọng các loại lỗi</CardTitle>
            <CardDescription>Mỗi loại lỗi chiếm bao nhiêu phần</CardDescription>
          </CardHeader>
          <CardContent>
            {analysis.categoryBreakdown.length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={analysis.categoryBreakdown}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ category, percentage }) => `${errorCategoryLabel(category)}: ${percentage.toFixed(0)}%`}
                    outerRadius={80}
                    fill="#8884d8"
                    dataKey="count"
                  >
                    {analysis.categoryBreakdown.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex items-center justify-center h-[300px] text-muted-foreground text-sm">
                Chưa có dữ liệu
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Time-Based Analysis */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg sm:text-xl">Thay đổi theo thời gian</CardTitle>
          <CardDescription>So sánh tuần này với tuần trước</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 mb-6">
            <div className="border rounded-lg p-4">
              <h4 className="text-sm font-medium text-muted-foreground mb-2">7 ngày qua</h4>
              <div className="space-y-1">
                <p className="text-lg font-bold">{analysis.timeBasedAnalysis.last7Days.checks} lần đối chiếu</p>
                <p className="text-sm text-muted-foreground">
                  {analysis.timeBasedAnalysis.last7Days.errors} lỗi
                </p>
                <p className="text-sm text-muted-foreground">
                  trung bình {analysis.timeBasedAnalysis.last7Days.avgErrors} lỗi/lần
                </p>
              </div>
            </div>

            <div className="border rounded-lg p-4">
              <h4 className="text-sm font-medium text-muted-foreground mb-2">7 ngày trước đó</h4>
              <div className="space-y-1">
                <p className="text-lg font-bold">{analysis.timeBasedAnalysis.previous7Days.checks} lần đối chiếu</p>
                <p className="text-sm text-muted-foreground">
                  {analysis.timeBasedAnalysis.previous7Days.errors} lỗi
                </p>
                <p className="text-sm text-muted-foreground">
                  trung bình {analysis.timeBasedAnalysis.previous7Days.avgErrors} lỗi/lần
                </p>
              </div>
            </div>

            <div className="border rounded-lg p-4">
              <h4 className="text-sm font-medium text-muted-foreground mb-2">Chênh lệch</h4>
              <div className="space-y-1">
                <p className={`text-lg font-bold ${analysis.timeBasedAnalysis.improvement > 0 ? 'text-green-600' : analysis.timeBasedAnalysis.improvement < 0 ? 'text-red-600' : ''}`}>
                  {analysis.timeBasedAnalysis.improvement > 0 ? '+' : ''}
                  {analysis.timeBasedAnalysis.improvement}%
                </p>
                <p className="text-sm text-muted-foreground">
                  {analysis.timeBasedAnalysis.improvement > 0
                    ? 'Đang tiến bộ, giữ nhịp nhé'
                    : analysis.timeBasedAnalysis.improvement < 0
                    ? 'Cần luyện thêm'
                    : 'Đi ngang'}
                </p>
              </div>
            </div>
          </div>

          {analysis.categoryBreakdown.length > 0 && (
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={analysis.categoryBreakdown}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="category" tickFormatter={errorCategoryLabel} tick={{ fontSize: 12 }} />
                <YAxis tick={{ fontSize: 12 }} />
                <Tooltip />
                <Legend wrapperStyle={{ fontSize: '12px' }} />
                <Bar dataKey="count" fill="#8884d8" name="Số lỗi" />
              </BarChart>
            </ResponsiveContainer>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
