import type { FromSchema, JSONSchema } from 'json-schema-to-ts';
import type { createTranslateCheckRepository } from '../../_storage/translateCheck.repository.ts';
import process from 'node:process';
import OpenAI from 'openai';
import { translateExplanationsToVietnamese } from '../../../common/vietnamese.ts';

const MODEL = 'gpt-4o-mini';

export const TranslateCheckResponseSchema = {
  type: 'object',
  properties: {
    detectedOriginalLanguage: {
      type: 'string',
      description: "The detected language of the original text (e.g., 'English', 'French', 'Spanish').",
    },
    detectedTranslatedLanguage: {
      type: 'string',
      description: "The detected language of the translated text (e.g., 'English', 'French', 'Spanish').",
    },
    translationErrors: {
      type: 'array',
      description: 'List of translation errors found by comparing the texts.',
      items: {
        type: 'object',
        properties: {
          message: {
            type: 'string',
            description: 'Description of the translation error.',
          },
          positions: {
            type: 'object',
            description: 'Positions of the error in both texts.',
            properties: {
              original: {
                type: 'array',
                description: 'Character positions in the original text where the error relates.',
                items: {
                  type: 'number',
                },
              },
              translated: {
                type: 'array',
                description: 'Character positions in the translated text where the error relates.',
                items: {
                  type: 'number',
                },
              },
            },
            required: ['original', 'translated'],
            additionalProperties: false,
          },
        },
        required: ['message', 'positions'],
        additionalProperties: false,
      },
    },
    correctedTranslation: {
      type: 'string',
      description: 'The corrected version of the translated text. Empty string if no errors are found.',
    },
  },
  required: ['detectedOriginalLanguage', 'detectedTranslatedLanguage', 'translationErrors', 'correctedTranslation'],
  additionalProperties: false,
} as const satisfies JSONSchema;

export type TranslateCheckResponse = FromSchema<typeof TranslateCheckResponseSchema>;

// Lazy initialization of OpenAI client
let openaiClient: OpenAI | null = null;

function getOpenAIClient(): OpenAI {
  if (!openaiClient) {
    // eslint-disable-next-line dot-notation
    const apiKey = process.env['OPENAI_API_KEY'];
    if (!apiKey) {
      throw new Error('OPENAI_API_KEY environment variable is not set');
    }
    openaiClient = new OpenAI({ apiKey });
  }
  return openaiClient;
}

// Validation function for OpenAI response
function validateTranslateCheckResponse(data: unknown): data is TranslateCheckResponse {
  if (!data || typeof data !== 'object') {
    return false;
  }

  const obj = data as Record<string, any>;

  // eslint-disable-next-line dot-notation
  if (typeof obj['detectedOriginalLanguage'] !== 'string'
    // eslint-disable-next-line dot-notation
    || typeof obj['detectedTranslatedLanguage'] !== 'string'
    // eslint-disable-next-line dot-notation
    || !Array.isArray(obj['translationErrors'])
    // eslint-disable-next-line dot-notation
    || typeof obj['correctedTranslation'] !== 'string') {
    return false;
  }

  // Validate each translation error
  // eslint-disable-next-line dot-notation
  for (const error of obj['translationErrors']) {
    if (!error || typeof error !== 'object') {
      return false;
    }
    if (typeof error.message !== 'string'
      || !error.positions
      || typeof error.positions !== 'object'
      || !Array.isArray(error.positions.original)
      || !Array.isArray(error.positions.translated)) {
      return false;
    }
    // Validate that position arrays contain numbers
    for (const pos of error.positions.original) {
      if (typeof pos !== 'number') {
        return false;
      }
    }
    for (const pos of error.positions.translated) {
      if (typeof pos !== 'number') {
        return false;
      }
    }
  }

  return true;
}

export function createCheckTranslationUsecase({
  translateCheckRepository,
}: {
  translateCheckRepository: ReturnType<typeof createTranslateCheckRepository>;
}) {
  return async ({
    userId,
    originalText,
    translatedText,
  }: {
    userId: string;
    originalText: string;
    translatedText: string;
  }) => {
    // Validate input
    if (!originalText || originalText.trim().length === 0) {
      throw new Error('Bạn chưa nhập văn bản gốc.');
    }

    if (!translatedText || translatedText.trim().length === 0) {
      throw new Error('Bạn chưa nhập bản dịch.');
    }

    if (originalText.length > 5000) {
      throw new Error('Văn bản gốc quá dài. Tối đa 5000 ký tự.');
    }

    if (translatedText.length > 5000) {
      throw new Error('Bản dịch quá dài. Tối đa 5000 ký tự.');
    }

    // Use OpenAI chat completion for translation checking
    let completion;
    try {
      const client = getOpenAIClient();
      completion = await client.chat.completions.create({
        model: MODEL,
        messages: [
          {
            role: 'system',
            content: `Bạn là trợ lý đối chiếu bản dịch cho người Việt đang học ngoại ngữ.
Người dùng đưa một văn bản gốc và bản dịch của họ, và cần biết bản dịch sai ở đâu,
được giải thích bằng tiếng Việt.

Việc cần làm:
1. Nhận ra ngôn ngữ của văn bản gốc và của bản dịch
2. Đối chiếu hai văn bản, chỉ ra các lỗi dịch
3. Đưa ra bản dịch đã sửa, nếu có lỗi

Các loại lỗi cần tìm:
- Dịch sai nghĩa
- Bỏ sót nội dung có trong bản gốc
- Thêm nội dung không có trong bản gốc
- Lỗi ngữ pháp trong bản dịch
- Sai ngữ cảnh
- Lệch sắc thái, giọng văn

Quy tắc về ngôn ngữ, quan trọng nhất:
- "message" phải viết bằng tiếng Việt, giải thích ngắn gọn lỗi và vì sao nó sai.
  Đặt từ ngoại ngữ được bàn tới trong ngoặc kép. Không viết bằng tiếng Anh.
- "correctedTranslation" phải giữ nguyên ngôn ngữ của bản dịch, không chuyển sang tiếng Việt
  (trừ khi bản dịch vốn đã là tiếng Việt).
- "detectedOriginalLanguage" và "detectedTranslatedLanguage" viết bằng tiếng Việt:
  "tiếng Anh", "tiếng Pháp", "tiếng Việt"...

Chỉ trả lời bằng JSON hợp lệ, đúng cấu trúc này:
{
  "detectedOriginalLanguage": "string",
  "detectedTranslatedLanguage": "string",
  "translationErrors": [
    {
      "message": "string mô tả lỗi, bằng tiếng Việt",
      "positions": {
        "original": [15, 20],
        "translated": [12, 18]
      }
    }
  ],
  "correctedTranslation": "string - bản dịch đã sửa, hoặc chuỗi rỗng nếu không có lỗi"
}

"positions" là các chỉ số ký tự nơi lỗi xuất hiện (ví dụ [15, 20]). Nếu là nội dung bị bỏ sót,
"original" trỏ vào phần bị thiếu và "translated" là mảng rỗng []. Nếu là nội dung thừa,
"original" là mảng rỗng [] và "translated" trỏ vào phần thừa.

"correctedTranslation" trả về chuỗi rỗng ("") khi không tìm thấy lỗi nào.

Ví dụ. Bản gốc tiếng Việt « Trời hôm nay đẹp quá », bản dịch tiếng Anh
« The weather today is very beauty »:
{
  "detectedOriginalLanguage": "tiếng Việt",
  "detectedTranslatedLanguage": "tiếng Anh",
  "translationErrors": [
    {
      "message": "« beauty » là danh từ; ở đây cần tính từ « beautiful ».",
      "positions": { "original": [], "translated": [30, 36] }
    }
  ],
  "correctedTranslation": "The weather today is very beautiful."
}

Chú ý ví dụ trên: "message" là tiếng Việt, còn "correctedTranslation" vẫn là
tiếng Anh. Ngôn ngữ của hai văn bản vào không quyết định ngôn ngữ của
"message" — "message" luôn luôn là tiếng Việt.`,
          },
          {
            role: 'user',
            // Le rappel voyage avec les textes : gpt-4o-mini suit le dernier
            // tour plus que le premier, et c'est là que la langue déraille.
            content: `Văn bản gốc: ${originalText}\n\nBản dịch: ${translatedText}\n\nNhớ: mọi "message" viết bằng tiếng Việt.`,
          },
        ],
        response_format: { type: 'json_object' },
      });
    } catch (error: unknown) {
      // Handle specific OpenAI errors using status codes and error properties
      if (error && typeof error === 'object' && 'status' in error) {
        const errorWithStatus = error as { status?: number; code?: string };
        if (errorWithStatus.status === 429) {
          throw new Error('Hệ thống đang nhận quá nhiều yêu cầu. Vui lòng thử lại sau ít phút.');
        } else if (errorWithStatus.status === 401) {
          throw new Error('Cấu hình khoá API không hợp lệ. Vui lòng báo cho quản trị viên.');
        } else if (errorWithStatus.status === 402 || errorWithStatus.code === 'insufficient_quota') {
          throw new Error('Hạn mức API đã hết. Vui lòng báo cho quản trị viên.');
        } else if (errorWithStatus.status && errorWithStatus.status >= 500) {
          throw new Error('Dịch vụ tạm thời gián đoạn. Vui lòng thử lại sau.');
        }
      }
      if (error instanceof Error) {
        throw new Error(`Lỗi khi gọi dịch vụ đối chiếu: ${error.message}`);
      }
      throw new Error('Không kết nối được tới dịch vụ đối chiếu.');
    }

    const responseText = completion.choices[0]?.message?.content;
    if (!responseText) {
      throw new Error('Dịch vụ đối chiếu không trả về kết quả.');
    }

    let responseParsed: unknown;
    try {
      responseParsed = JSON.parse(responseText);
    } catch (error) {
      throw new Error('Kết quả trả về không đọc được. Vui lòng thử lại.', { cause: error });
    }

    // Validate the parsed response matches expected schema
    if (!validateTranslateCheckResponse(responseParsed)) {
      throw new Error('Kết quả trả về thiếu dữ liệu. Vui lòng thử lại.');
    }

    // Save to database
    // Le filet : si le modèle a expliqué en anglais malgré tout, on repasse.
    const explanations = await translateExplanationsToVietnamese({
      client: getOpenAIClient(),
      model: MODEL,
      explanations: responseParsed.translationErrors.map((error) => error.message),
    });
    const translationErrors = responseParsed.translationErrors.map((error, index) => ({
      ...error,
      message: explanations[index] ?? error.message,
    }));

    const result = await translateCheckRepository.saveResult({
      userId,
      originalText,
      translatedText,
      detectedOriginalLanguage: responseParsed.detectedOriginalLanguage,
      detectedTranslatedLanguage: responseParsed.detectedTranslatedLanguage,
      translationErrors,
      correctedTranslation: responseParsed.correctedTranslation,
    });

    return result;
  };
}
