export type StarredTranslationCheck = {
  userId: string;
  translationCheckId: string;
  starredAt: Date;
};

export function formatDocumentToModel({ document }: { document: any }): StarredTranslationCheck {
  return {
    userId: document.userId,
    translationCheckId: document.translationCheckId.toString(),
    starredAt: document.starredAt,
  };
}
