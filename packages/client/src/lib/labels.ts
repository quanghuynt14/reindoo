// Les libellés que l'app affiche en vietnamien à partir de codes stables.
// Les codes eux-mêmes (catégories d'erreur, priorités, tendances) restent en
// anglais côté serveur et base : ils servent de clés, pas de texte.

const ERROR_CATEGORIES: Record<string, string> = {
  spelling: 'Chính tả',
  grammar: 'Ngữ pháp',
  punctuation: 'Dấu câu',
  style: 'Văn phong',
  word_choice: 'Dùng từ',
  sentence_structure: 'Cấu trúc câu',
  accuracy: 'Độ chính xác',
  fluency: 'Độ tự nhiên',
  terminology: 'Thuật ngữ',
  other: 'Khác',
}

export function errorCategoryLabel(category: string): string {
  const key = category.toLowerCase().replace(/[\s-]+/g, '_')
  return ERROR_CATEGORIES[key] ?? category
}

const LANGUAGES: Record<string, string> = {
  en: 'tiếng Anh',
  vi: 'tiếng Việt',
  fr: 'tiếng Pháp',
  es: 'tiếng Tây Ban Nha',
  de: 'tiếng Đức',
  english: 'tiếng Anh',
  vietnamese: 'tiếng Việt',
  french: 'tiếng Pháp',
  spanish: 'tiếng Tây Ban Nha',
  german: 'tiếng Đức',
}

export function languageLabel(language: string): string {
  return LANGUAGES[language.toLowerCase()] ?? language
}

const PRIORITIES: Record<string, string> = {
  high: 'Ưu tiên cao',
  medium: 'Ưu tiên vừa',
  low: 'Ưu tiên thấp',
}

export function priorityLabel(priority: string): string {
  return PRIORITIES[priority] ?? priority
}

const TRENDS: Record<string, string> = {
  improving: 'Đang tiến bộ',
  stable: 'Đi ngang',
  worsening: 'Đang đi xuống',
}

export function trendLabel(trend: string): string {
  return TRENDS[trend] ?? trend
}

// Le fuseau et le format viennent du navigateur ; seule la locale est imposée.
export function formatDateTime(value: string | number | Date): string {
  return new Date(value).toLocaleString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function formatDate(value: string | number | Date): string {
  return new Date(value).toLocaleDateString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  })
}

export function formatNumber(value: number): string {
  return value.toLocaleString('vi-VN')
}

/** « 3 lỗi » : le vietnamien n'accorde pas, mais le classificateur change. */
export function countLabel(count: number, noun: string): string {
  return `${formatNumber(count)} ${noun}`
}

const GAME_CATEGORIES: Record<string, string> = {
  dictionary: 'Từ điển',
  grammar: 'Ngữ pháp',
  translation: 'Bản dịch',
}

export function gameCategoryLabel(category: string): string {
  return GAME_CATEGORIES[category] ?? category
}

const QUESTION_TYPES: Record<string, string> = {
  'word-to-translation': 'Từ → nghĩa',
  'translation-to-word': 'Nghĩa → từ',
  'synonym-match': 'Từ đồng nghĩa',
  'antonym-match': 'Từ trái nghĩa',
  'fill-blank': 'Điền vào chỗ trống',
  'definition-match': 'Chọn định nghĩa',
  'true-false': 'Đúng hay sai',
  'correct-sentence': 'Chọn câu đúng',
  'error-category': 'Loại lỗi',
  'suggest-correction': 'Chọn cách sửa',
  'count-errors': 'Đếm lỗi',
  'choose-correct-translation': 'Chọn bản dịch đúng',
  'translation-true-false': 'Bản dịch đúng hay sai',
  'detect-original-language': 'Nhận ra ngôn ngữ gốc',
  'detect-translated-language': 'Nhận ra ngôn ngữ dịch',
  'count-translation-errors': 'Đếm lỗi dịch',
  'match-translation': 'Ghép bản dịch',
}

export function questionTypeLabel(type: string): string {
  return QUESTION_TYPES[type] ?? type
}
