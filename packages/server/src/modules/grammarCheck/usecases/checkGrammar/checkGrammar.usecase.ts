import type { FromSchema, JSONSchema } from 'json-schema-to-ts';
import type { createGrammarCheckRepository } from '../../_storage/grammarCheck.repository.ts';
import process from 'node:process';
import OpenAI from 'openai';
import { translateExplanationsToVietnamese } from '../../../common/vietnamese.ts';

const MODEL = 'gpt-4o-mini';

export const GrammarCheckResponseSchema = {
  type: 'object',
  properties: {
    correctedText: {
      type: 'string',
      description: 'The corrected version of the input text with all grammar errors fixed.',
    },
    detectedLanguage: {
      type: 'string',
      description: "The detected language of the input text (e.g., 'English', 'French', 'Spanish').",
    },
    grammarErrors: {
      type: 'array',
      description: 'List of grammar errors found in the text.',
      items: {
        type: 'object',
        properties: {
          message: {
            type: 'string',
            description: 'Description of the grammar error.',
          },
          category: {
            type: 'string',
            description: "Category of the error (e.g., 'spelling', 'grammar', 'punctuation', 'style').",
          },
          position: {
            type: 'object',
            description: 'Position of the error in the original text.',
            properties: {
              start: {
                type: 'number',
                description: 'Start position of the error in the text.',
              },
              end: {
                type: 'number',
                description: 'End position of the error in the text.',
              },
            },
            required: ['start', 'end'],
            additionalProperties: false,
          },
          suggestion: {
            type: 'string',
            description: 'Suggested correction for the error.',
          },
        },
        required: ['message', 'category', 'position', 'suggestion'],
        additionalProperties: false,
      },
    },
  },
  required: ['correctedText', 'detectedLanguage', 'grammarErrors'],
  additionalProperties: false,
} as const satisfies JSONSchema;

export type GrammarCheckResponse = FromSchema<typeof GrammarCheckResponseSchema>;

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
function validateGrammarCheckResponse(data: unknown): data is GrammarCheckResponse {
  if (!data || typeof data !== 'object') {
    return false;
  }

  const obj = data as Record<string, any>;

  // eslint-disable-next-line dot-notation
  if (typeof obj['correctedText'] !== 'string'
    // eslint-disable-next-line dot-notation
    || typeof obj['detectedLanguage'] !== 'string'
    // eslint-disable-next-line dot-notation
    || !Array.isArray(obj['grammarErrors'])) {
    return false;
  }

  // Validate each grammar error
  // eslint-disable-next-line dot-notation
  for (const error of obj['grammarErrors']) {
    if (!error || typeof error !== 'object') {
      return false;
    }
    if (typeof error.message !== 'string'
      || typeof error.category !== 'string'
      || typeof error.suggestion !== 'string'
      || !error.position
      || typeof error.position !== 'object'
      || typeof error.position.start !== 'number'
      || typeof error.position.end !== 'number') {
      return false;
    }
  }

  return true;
}

export function createCheckGrammarUsecase({
  grammarCheckRepository,
}: {
  grammarCheckRepository: ReturnType<typeof createGrammarCheckRepository>;
}) {
  return async ({ userId, text }: { userId: string; text: string }) => {
    // Validate input
    if (!text || text.trim().length === 0) {
      throw new Error('Bạn chưa nhập văn bản nào để kiểm tra.');
    }

    if (text.length > 5000) {
      throw new Error('Văn bản quá dài. Tối đa 5000 ký tự.');
    }

    // Use OpenAI chat completion for grammar checking
    let completion;
    try {
      const client = getOpenAIClient();
      completion = await client.chat.completions.create({
        model: MODEL,
        messages: [
          {
            role: 'system',
            content: `Bạn là trợ lý kiểm tra ngữ pháp cho người Việt đang học ngoại ngữ.
Người dùng viết một đoạn văn bằng ngoại ngữ (thường là tiếng Anh hoặc tiếng Pháp)
và cần biết mình sai ở đâu, bằng tiếng Việt.

Quy tắc về ngôn ngữ, quan trọng nhất:
- "correctedText" phải giữ nguyên ngôn ngữ của văn bản gốc. Tuyệt đối không dịch sang tiếng Việt.
- "message" phải viết bằng tiếng Việt, giải thích ngắn gọn lỗi sai và vì sao nó sai.
  Ví dụ: "Chủ ngữ số ít nên động từ phải chia \"goes\"." Không viết bằng tiếng Anh.
- "suggestion" là phần thay thế đúng, giữ nguyên ngôn ngữ của văn bản gốc.
- "category" phải là đúng một trong bốn giá trị tiếng Anh sau, viết thường:
  spelling, grammar, punctuation, style. Đây là mã phân loại, không phải câu chữ hiển thị.
- "detectedLanguage" viết bằng tiếng Việt: "tiếng Anh", "tiếng Pháp", "tiếng Tây Ban Nha"...

Cách viết "message" cho người Việt:
- Xưng hô trung tính, không "bạn phải", không dạy đời. Nói thẳng lỗi là gì.
- Ngắn, một câu là đủ. Nếu cần đối chiếu, đặt từ ngoại ngữ trong ngoặc kép.
- Không dùng thuật ngữ ngữ pháp tiếng Anh chưa dịch ("past participle") mà dùng
  cách nói quen thuộc ("phân từ quá khứ").

Vị trí lỗi: "position" là chỉ số ký tự trong văn bản gốc, tính từ 0, [start, end).
Đếm theo ký tự Unicode của chuỗi gốc, không tính lại sau khi sửa.

Trả lời bằng một đối tượng JSON đúng cấu trúc này:
{
  "correctedText": "string",
  "detectedLanguage": "string",
  "grammarErrors": [
    {
      "message": "string",
      "category": "spelling|grammar|punctuation|style",
      "position": { "start": number, "end": number },
      "suggestion": "string"
    }
  ]
}

Ví dụ. Với văn bản vào: she go to school evry day
{
  "correctedText": "She goes to school every day.",
  "detectedLanguage": "tiếng Anh",
  "grammarErrors": [
    {
      "message": "Chữ đầu câu phải viết hoa.",
      "category": "punctuation",
      "position": { "start": 0, "end": 3 },
      "suggestion": "She"
    },
    {
      "message": "Chủ ngữ số ít ở thì hiện tại đơn nên động từ phải thêm « -es ».",
      "category": "grammar",
      "position": { "start": 4, "end": 6 },
      "suggestion": "goes"
    },
    {
      "message": "« evry » viết sai chính tả.",
      "category": "spelling",
      "position": { "start": 17, "end": 21 },
      "suggestion": "every"
    }
  ]
}

Chú ý ví dụ trên: văn bản vào là tiếng Anh, "correctedText" và "suggestion"
vẫn là tiếng Anh, còn "message" là tiếng Việt. Ngôn ngữ của văn bản vào không
quyết định ngôn ngữ của "message" — "message" luôn luôn là tiếng Việt.`,
          },
          {
            // Le rappel voyage avec le texte : gpt-4o-mini suit le dernier
            // tour plus que le premier, et c'est là que la langue déraille.
            role: 'user',
            content: `Kiểm tra văn bản sau. Nhớ: mọi "message" viết bằng tiếng Việt.\n\n${text}`,
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
        throw new Error(`Lỗi khi gọi dịch vụ kiểm tra: ${error.message}`);
      }
      throw new Error('Không kết nối được tới dịch vụ kiểm tra.');
    }

    const responseText = completion.choices[0]?.message?.content;
    if (!responseText) {
      throw new Error('Dịch vụ kiểm tra không trả về kết quả.');
    }

    let responseParsed: unknown;
    try {
      responseParsed = JSON.parse(responseText);
    } catch (error) {
      throw new Error('Kết quả trả về không đọc được. Vui lòng thử lại.', { cause: error });
    }

    // Validate the parsed response matches expected schema
    if (!validateGrammarCheckResponse(responseParsed)) {
      throw new Error('Kết quả trả về thiếu dữ liệu. Vui lòng thử lại.');
    }

    // Le filet : si le modèle a expliqué en anglais malgré tout, on repasse.
    const explanations = await translateExplanationsToVietnamese({
      client: getOpenAIClient(),
      model: MODEL,
      explanations: responseParsed.grammarErrors.map((error) => error.message),
    });
    const grammarErrors = responseParsed.grammarErrors.map((error, index) => ({
      ...error,
      message: explanations[index] ?? error.message,
    }));

    // Save to database
    const result = await grammarCheckRepository.saveResult({
      userId,
      originalText: text,
      correctedText: responseParsed.correctedText,
      detectedLanguage: responseParsed.detectedLanguage,
      grammarErrors,
    });

    return result;
  };
}
