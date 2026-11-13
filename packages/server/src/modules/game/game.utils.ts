// Utility functions for game module

export function shuffleArray<T>(array: readonly T[]): T[] {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const temp = shuffled[i];
    shuffled[i] = shuffled[j]!;
    shuffled[j] = temp!;
  }
  return shuffled;
}

export function generateId(): string {
  return crypto.randomUUID();
}

export function formatLanguage(lang: string): string {
  const map: Record<string, string> = {
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
  };
  return map[lang.toLowerCase()] || lang;
}

// Les catégories restent des codes anglais côté modèle et base ; seul l'affichage change.
export function formatErrorCategory(category: string): string {
  const map: Record<string, string> = {
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
  };
  const key = category.toLowerCase().replace(/[\s-]+/g, '_');
  return map[key] || category
    .split('_')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}
