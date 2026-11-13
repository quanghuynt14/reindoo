export type ErrorPattern = {
  category: string;
  count: number;
  percentage: number;
  examples: Array<{
    message: string;
    suggestion: string;
    textSnippet: string;
  }>;
  trend: 'improving' | 'stable' | 'worsening';
};

export type ImprovementArea = {
  category: string;
  errorCount: number;
  priority: 'high' | 'medium' | 'low';
  recommendation: string;
  resources: string[];
};

export type AnalysisResult = {
  errorPatterns: ErrorPattern[];
  improvementAreas: ImprovementArea[];
  progressMetrics: {
    totalChecks: number;
    totalErrors: number;
    averageErrorsPerCheck: number;
    improvementRate: number;
    recentTrend: 'improving' | 'stable' | 'worsening';
  };
  categoryBreakdown: Array<{
    category: string;
    count: number;
    percentage: number;
  }>;
  timeBasedAnalysis: {
    last7Days: { checks: number; errors: number; avgErrors: number };
    previous7Days: { checks: number; errors: number; avgErrors: number };
    improvement: number;
  };
};

type GrammarCheckRepository = ReturnType<typeof import('../../_storage/grammarCheck.repository.ts').createGrammarCheckRepository>;

// Constants
const MAX_ANALYSIS_RECORDS = 1000; // Limit to prevent performance issues with large datasets
const SNIPPET_CONTEXT_LENGTH = 20; // Characters to show before and after error in examples

// Helper function to calculate percentage change
function calculatePercentageChange(oldValue: number, newValue: number): number {
  if (oldValue === 0) {
    return 0;
  }
  return ((oldValue - newValue) / oldValue) * 100;
}

export function createGetAnalysisUsecase({
  grammarCheckRepository,
}: {
  grammarCheckRepository: GrammarCheckRepository;
}) {
  return async function getAnalysis({ userId }: { userId: string }): Promise<AnalysisResult> {
    // Get user's recent grammar checks (limited for performance)
    const allChecks = await grammarCheckRepository.findByUserId({ userId, limit: MAX_ANALYSIS_RECORDS });

    if (allChecks.length === 0) {
      return {
        errorPatterns: [],
        improvementAreas: [],
        progressMetrics: {
          totalChecks: 0,
          totalErrors: 0,
          averageErrorsPerCheck: 0,
          improvementRate: 0,
          recentTrend: 'stable',
        },
        categoryBreakdown: [],
        timeBasedAnalysis: {
          last7Days: { checks: 0, errors: 0, avgErrors: 0 },
          previous7Days: { checks: 0, errors: 0, avgErrors: 0 },
          improvement: 0,
        },
      };
    }

    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);

    // Filter checks by time period
    const last7DaysChecks = allChecks.filter((check) => new Date(check.createdAt) >= sevenDaysAgo);
    const previous7DaysChecks = allChecks.filter(
      (check) => new Date(check.createdAt) >= fourteenDaysAgo && new Date(check.createdAt) < sevenDaysAgo,
    );

    // Calculate metrics
    const totalErrors = allChecks.reduce((sum, check) => sum + check.grammarErrors.length, 0);
    const avgErrorsPerCheck = totalErrors / allChecks.length;

    const last7DaysErrors = last7DaysChecks.reduce((sum, check) => sum + check.grammarErrors.length, 0);
    const previous7DaysErrors = previous7DaysChecks.reduce((sum, check) => sum + check.grammarErrors.length, 0);

    const last7DaysAvg = last7DaysChecks.length > 0 ? last7DaysErrors / last7DaysChecks.length : 0;
    const previous7DaysAvg = previous7DaysChecks.length > 0 ? previous7DaysErrors / previous7DaysChecks.length : 0;

    const improvementRate = calculatePercentageChange(previous7DaysAvg, last7DaysAvg);

    const recentTrend: 'improving' | 'stable' | 'worsening'
      = improvementRate > 5 ? 'improving' : improvementRate < -5 ? 'worsening' : 'stable';

    // Analyze error patterns by category
    const errorsByCategory: Record<string, { count: number; examples: Array<{ message: string; suggestion: string; textSnippet: string }> }> = {};

    allChecks.forEach((check) => {
      check.grammarErrors.forEach((error) => {
        const category = error.category || 'other';
        if (!errorsByCategory[category]) {
          errorsByCategory[category] = { count: 0, examples: [] };
        }
        errorsByCategory[category].count++;

        // Add example (limit to 3 per category)
        if (errorsByCategory[category].examples.length < 3) {
          const snippet = check.originalText.substring(
            Math.max(0, error.position.start - SNIPPET_CONTEXT_LENGTH),
            Math.min(check.originalText.length, error.position.end + SNIPPET_CONTEXT_LENGTH),
          );
          errorsByCategory[category].examples.push({
            message: error.message,
            suggestion: error.suggestion,
            textSnippet: snippet,
          });
        }
      });
    });

    // Calculate trends for each category
    const categoryTrends: Record<string, 'improving' | 'stable' | 'worsening'> = {};
    Object.keys(errorsByCategory).forEach((category) => {
      const last7DaysCategoryErrors = last7DaysChecks.reduce(
        (sum, check) => sum + check.grammarErrors.filter((e) => (e.category || 'other') === category).length,
        0,
      );
      const previous7DaysCategoryErrors = previous7DaysChecks.reduce(
        (sum, check) => sum + check.grammarErrors.filter((e) => (e.category || 'other') === category).length,
        0,
      );

      const categoryChange = calculatePercentageChange(previous7DaysCategoryErrors, last7DaysCategoryErrors);

      categoryTrends[category] = categoryChange > 5 ? 'improving' : categoryChange < -5 ? 'worsening' : 'stable';
    });

    // Create error patterns
    const errorPatterns: ErrorPattern[] = Object.entries(errorsByCategory)
      .map(([category, data]) => ({
        category,
        count: data.count,
        percentage: (data.count / totalErrors) * 100,
        examples: data.examples,
        trend: categoryTrends[category] || 'stable',
      }))
      .sort((a, b) => b.count - a.count);

    // Generate improvement areas
    const improvementAreas: ImprovementArea[] = errorPatterns
      .filter((pattern) => pattern.count > 0)
      .map((pattern) => {
        const priority: 'high' | 'medium' | 'low'
          = pattern.percentage > 30 ? 'high' : pattern.percentage > 15 ? 'medium' : 'low';

        const recommendations: Record<string, string> = {
          spelling: 'Xem lại quy tắc chính tả và những từ hay viết sai. Đọc lại bài trước khi gửi, hoặc bật công cụ kiểm tra chính tả khi viết.',
          grammar: 'Ôn lại sự hoà hợp giữa chủ ngữ và động từ, cách dùng thì cho nhất quán, và cấu trúc câu. Tập viết câu đủ thành phần.',
          punctuation: 'Học cách dùng dấu phẩy, dấu nháy đơn sở hữu và dấu kết câu. Đọc to câu văn để nhận ra chỗ cần ngắt.',
          style: 'Ưu tiên rõ và gọn. Hạn chế câu bị động khi không cần thiết, và thay đổi độ dài câu cho đỡ đơn điệu.',
        };

        const resources: Record<string, string[]> = {
          spelling: [
            'Làm bài tập chính tả trực tuyến',
            'Ghi lại danh sách riêng những từ mình hay viết sai',
            'Tự đặt mẹo nhớ cho các từ khó',
          ],
          grammar: [
            'Ôn lại các quy tắc ngữ pháp cơ bản đều đặn',
            'Đọc sách báo bằng ngôn ngữ đang học',
            'Làm bài tập ngữ pháp',
          ],
          punctuation: [
            'Đọc tài liệu hướng dẫn về dấu câu',
            'Xem những văn bản đặt dấu câu chuẩn mực',
            'Tập tìm lỗi dấu câu trong bài của mình',
          ],
          style: [
            'Đọc cẩm nang văn phong của ngôn ngữ đang học',
            'Phân tích những bài viết hay',
            'Tập viết lại câu cho gọn hơn',
          ],
        };

        return {
          category: pattern.category,
          errorCount: pattern.count,
          priority,
          recommendation: recommendations[pattern.category] || 'Luyện thêm ở phần này để viết chắc tay hơn.',
          resources: resources[pattern.category] || ['Luyện tập đều đặn', 'Nhờ người khác đọc và góp ý'],
        };
      })
      .sort((a, b) => {
        const priorityOrder = { high: 0, medium: 1, low: 2 };
        return priorityOrder[a.priority] - priorityOrder[b.priority];
      });

    // Category breakdown
    const categoryBreakdown = errorPatterns.map((pattern) => ({
      category: pattern.category,
      count: pattern.count,
      percentage: pattern.percentage,
    }));

    return {
      errorPatterns,
      improvementAreas,
      progressMetrics: {
        totalChecks: allChecks.length,
        totalErrors,
        averageErrorsPerCheck: Number.parseFloat(avgErrorsPerCheck.toFixed(2)),
        improvementRate: Number.parseFloat(improvementRate.toFixed(1)),
        recentTrend,
      },
      categoryBreakdown,
      timeBasedAnalysis: {
        last7Days: {
          checks: last7DaysChecks.length,
          errors: last7DaysErrors,
          avgErrors: Number.parseFloat(last7DaysAvg.toFixed(2)),
        },
        previous7Days: {
          checks: previous7DaysChecks.length,
          errors: previous7DaysErrors,
          avgErrors: Number.parseFloat(previous7DaysAvg.toFixed(2)),
        },
        improvement: Number.parseFloat(improvementRate.toFixed(1)),
      },
    };
  };
}
