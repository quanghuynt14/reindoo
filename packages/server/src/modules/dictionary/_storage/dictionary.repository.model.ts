import type { Word } from '@practice/shared';

export function formatDocumentToModel({ document }: { document: any }): Word {
  return {
    id: document._id.toString(),
    word: document.word,
    sourceLanguage: document.sourceLanguage,
    targetLanguage: document.targetLanguage,
    translated: document.translated,
    explains: document.explains,
    // Ce que le lexique compilé apporte et que la version générée n'avait pas.
    // Optionnels : les documents écrits avant la bascule ne les portent pas.
    ...(document.ipa?.length ? { ipa: document.ipa } : {}),
    ...(document.audio ? { audio: document.audio } : {}),
    ...(document.wiki ? { wiki: document.wiki } : {}),
    ...(document.derived?.length ? { derived: document.derived } : {}),
  };
}
