export type ErrorPattern = {
  category: string;
  count: number;
  percentage: number;
  examples: Array<{
    message: string;
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

type TranslateCheckRepository = ReturnType<typeof import('../../_storage/translateCheck.repository.ts').createTranslateCheckRepository>;

// Constants
const MAX_ANALYSIS_RECORDS = 1000; // Limit to prevent performance issues with large datasets
const SNIPPET_CONTEXT_LENGTH = 30; // Characters to show before and after error in examples

// Helper function to calculate percentage change
function calculatePercentageChange(oldValue: number, newValue: number): number {
  if (oldValue === 0) {
    return 0;
  }
  return ((oldValue - newValue) / oldValue) * 100;
}

// Helper function to extract text snippet with context
// When no explicit error positions are provided, fall back to a generic snippet
// from the beginning of the text. This shows up to SNIPPET_CONTEXT_LENGTH * 2
// characters so that callers still get some context even if the exact location
// of the issue is unknown.
function extractSnippet(text: string, positions: number[]): string {
  if (positions.length === 0) {
    return text.substring(0, Math.min(text.length, SNIPPET_CONTEXT_LENGTH * 2));
  }

  // Use first and last positions to create a better context snippet
  const firstPos = positions[0] ?? 0;
  const lastPos = positions.length > 1 ? positions[positions.length - 1] ?? firstPos : firstPos;

  const start = Math.max(0, firstPos - SNIPPET_CONTEXT_LENGTH);
  const end = Math.min(text.length, lastPos + SNIPPET_CONTEXT_LENGTH);
  return text.substring(start, end);
}

export function createGetAnalysisUsecase({
  translateCheckRepository,
}: {
  translateCheckRepository: TranslateCheckRepository;
}) {
  return async function getAnalysis({ userId }: { userId: string }): Promise<AnalysisResult> {
    // Get user's recent translation checks (limited for performance)
    const allChecks = await translateCheckRepository.findByUserId({ userId, limit: MAX_ANALYSIS_RECORDS });

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
    const totalErrors = allChecks.reduce((sum, check) => sum + check.translationErrors.length, 0);
    const avgErrorsPerCheck = totalErrors / allChecks.length;

    const last7DaysErrors = last7DaysChecks.reduce((sum, check) => sum + check.translationErrors.length, 0);
    const previous7DaysErrors = previous7DaysChecks.reduce((sum, check) => sum + check.translationErrors.length, 0);

    const last7DaysAvg = last7DaysChecks.length > 0 ? last7DaysErrors / last7DaysChecks.length : 0;
    const previous7DaysAvg = previous7DaysChecks.length > 0 ? previous7DaysErrors / previous7DaysChecks.length : 0;

    const improvementRate = calculatePercentageChange(previous7DaysAvg, last7DaysAvg);

    const recentTrend: 'improving' | 'stable' | 'worsening'
      = improvementRate > 5 ? 'improving' : improvementRate < -5 ? 'worsening' : 'stable';

    // Analyze error patterns by category (categorize based on error characteristics)
    const errorsByCategory: Record<string, { count: number; examples: Array<{ message: string; textSnippet: string }> }> = {};

    allChecks.forEach((check) => {
      check.translationErrors.forEach((error) => {
        // Categorize translation errors based on their characteristics
        const category = categorizeTranslationError(error.message);

        if (!errorsByCategory[category]) {
          errorsByCategory[category] = { count: 0, examples: [] };
        }
        errorsByCategory[category].count++;

        // Add example (limit to 3 per category)
        if (errorsByCategory[category].examples.length < 3) {
          // Use positional information when available to extract snippets from original/translated text.
          const originalSnippet
            = error.positions.original && error.positions.original.length > 0
              ? extractSnippet(check.originalText, error.positions.original)
              : '';
          const translatedSnippet
            = error.positions.translated && error.positions.translated.length > 0
              ? extractSnippet(check.translatedText, error.positions.translated)
              : '';
          const snippetParts = [originalSnippet, translatedSnippet].filter((part) => part);
          const snippet = snippetParts.join(' → ');

          // Only add example if we have at least some snippet content
          if (snippet) {
            errorsByCategory[category].examples.push({
              message: error.message,
              textSnippet: snippet,
            });
          }
        }
      });
    });

    // Calculate trends for each category
    const categoryTrends: Record<string, 'improving' | 'stable' | 'worsening'> = {};
    Object.keys(errorsByCategory).forEach((category) => {
      const last7DaysCategoryErrors = last7DaysChecks.reduce(
        (sum, check) => sum + check.translationErrors.filter((e) => categorizeTranslationError(e.message) === category).length,
        0,
      );
      const previous7DaysCategoryErrors = previous7DaysChecks.reduce(
        (sum, check) => sum + check.translationErrors.filter((e) => categorizeTranslationError(e.message) === category).length,
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
          accuracy: 'Giữ đúng nghĩa và ngữ cảnh của bản gốc. Tránh dịch bám từng chữ.',
          fluency: 'Làm cho bản dịch nghe tự nhiên trong ngôn ngữ đích. Đọc nhiều văn bản bản ngữ để quen lối diễn đạt.',
          terminology: 'Mở rộng vốn từ ở cả hai ngôn ngữ. Tự lập một bảng thuật ngữ cho lĩnh vực mình hay dịch.',
          grammar: 'Ôn ngữ pháp của cả ngôn ngữ nguồn lẫn ngôn ngữ đích, nhất là chỗ hai bên khác nhau về cấu trúc câu.',
          style: 'Chỉnh giọng văn cho khớp với bản gốc, và cân nhắc người đọc bản dịch là ai.',
          other: 'Đọc kỹ từng lỗi được chỉ ra để hiểu vấn đề nằm ở đâu. Nếu được, nhờ người dịch có kinh nghiệm xem lại.',
        };

        const resources: Record<string, string[]> = {
          accuracy: [
            'Đọc song song bản gốc và bản dịch',
            'Dựa vào ngữ cảnh để đoán đúng ý người viết',
            'Đối chiếu cách dịch với nhiều nguồn',
          ],
          fluency: [
            'Đọc nhiều bằng ngôn ngữ đích',
            'Nghe người bản ngữ và ghi lại các cách nói tự nhiên',
            'Tập dịch nhiều thể loại văn bản khác nhau',
          ],
          terminology: [
            'Lập bảng thuật ngữ riêng cho lĩnh vực của mình',
            'Tra từ điển chuyên ngành',
            'Đọc bản dịch của người dịch chuyên nghiệp',
          ],
          grammar: [
            'Học ngữ pháp đối chiếu giữa hai ngôn ngữ',
            'Tập nhận ra các khuôn cấu trúc lặp lại',
            'Xem lại những lỗi ngữ pháp thường gặp khi dịch',
          ],
          style: [
            'Phân tích bản dịch của những văn bản cùng thể loại',
            'Đọc cẩm nang văn phong cho từng ngữ cảnh',
            'Tập đổi giọng văn cho từng nhóm người đọc',
          ],
          other: [
            'Đọc kỹ nội dung từng lỗi được chỉ ra',
            'Nhờ người dịch có kinh nghiệm góp ý',
            'Dịch đều đặn để nhận ra lỗi nào của mình hay lặp lại',
          ],
        };

        return {
          category: pattern.category,
          errorCount: pattern.count,
          priority,
          recommendation: recommendations[pattern.category] || 'Luyện thêm ở phần này để dịch chắc tay hơn.',
          resources: resources[pattern.category] || ['Luyện tập đều đặn', 'Nhờ người bản ngữ góp ý'],
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

// Helper function to escape regex special characters
function escapeRegex(pattern: string): string {
  return pattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Helper function to check if a message contains a whole word
function containsWholeWord(message: string, pattern: string): boolean {
  const escaped = escapeRegex(pattern);
  const regex = new RegExp(`\\b${escaped}\\b`, 'i');
  return regex.test(message);
}

// Helper function to categorize translation errors
function categorizeTranslationError(message: string): string {
  if (
    containsWholeWord(message, 'meaning')
    || containsWholeWord(message, 'incorrect')
    || containsWholeWord(message, 'wrong')
  ) {
    return 'accuracy';
  }
  if (
    containsWholeWord(message, 'natural')
    || containsWholeWord(message, 'awkward')
    || containsWholeWord(message, 'fluency')
  ) {
    return 'fluency';
  }
  if (
    containsWholeWord(message, 'term')
    || containsWholeWord(message, 'vocabulary')
    || containsWholeWord(message, 'word choice')
  ) {
    return 'terminology';
  }
  if (
    containsWholeWord(message, 'grammar')
    || containsWholeWord(message, 'tense')
    || containsWholeWord(message, 'structure')
  ) {
    return 'grammar';
  }
  if (
    containsWholeWord(message, 'style')
    || containsWholeWord(message, 'tone')
    || containsWholeWord(message, 'register')
  ) {
    return 'style';
  }

  return 'other';
}
