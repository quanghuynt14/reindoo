import type OpenAI from 'openai';

/**
 * Le modèle rend parfois ses explications dans la langue du texte examiné,
 * malgré une invite écrite en vietnamien : gpt-4o-mini suit le contenu de
 * l'utilisateur plus que la consigne. Une explication en anglais sur une
 * phrase anglaise est précisément ce que l'app existe pour éviter.
 *
 * Le vietnamien écrit ne va pas loin sans un de ces caractères — « Chữ đầu
 * câu phải viết hoa » en porte quatre. Une explication qui n'en contient
 * aucun n'est pas du vietnamien.
 */
const VIETNAMESE_LETTERS
  = /[ăâđêôơưàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ]/i;

export function looksVietnamese(text: string): boolean {
  return VIETNAMESE_LETTERS.test(text);
}

/**
 * Repasse les explications non vietnamiennes dans un second appel, plutôt que
 * de les servir telles quelles. Le coût n'est payé que quand la première
 * réponse a désobéi.
 *
 * Rend le tableau d'origine si quoi que ce soit tourne mal : une explication
 * en anglais reste plus utile qu'une erreur, et l'utilisateur a déjà attendu.
 */
export async function translateExplanationsToVietnamese({
  client,
  model,
  explanations,
}: {
  client: OpenAI;
  model: string;
  explanations: string[];
}): Promise<string[]> {
  const needsWork = explanations.some((explanation) => !looksVietnamese(explanation));
  if (!needsWork) {
    return explanations;
  }

  try {
    const completion = await client.chat.completions.create({
      model,
      messages: [
        {
          role: 'system',
          content: `Bạn dịch các lời giải thích lỗi ngôn ngữ sang tiếng Việt, cho người Việt đang học ngoại ngữ.

Quy tắc:
- Dịch trọn vẹn sang tiếng Việt, tự nhiên, ngắn gọn, mỗi câu một ý.
- Giữ nguyên trong ngoặc kép những từ ngoại ngữ đang được bàn tới.
- Giữ đúng thứ tự và đúng số phần tử.
- Phần tử nào đã là tiếng Việt thì để nguyên.

Trả lời bằng JSON đúng dạng: { "translations": ["...", "..."] }`,
        },
        {
          role: 'user',
          content: JSON.stringify({ explanations }),
        },
      ],
      response_format: { type: 'json_object' },
    });

    const raw = completion.choices[0]?.message?.content;
    if (!raw) {
      return explanations;
    }

    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || !('translations' in parsed)) {
      return explanations;
    }

    const { translations } = parsed as { translations: unknown };
    if (!Array.isArray(translations) || translations.length !== explanations.length) {
      return explanations;
    }

    return explanations.map((explanation, index) => {
      const candidate = translations[index];
      return typeof candidate === 'string' && candidate.trim().length > 0
        ? candidate
        : explanation;
    });
  } catch {
    return explanations;
  }
}
