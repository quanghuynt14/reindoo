export type StarredGrammarCheck = {
  userId: string;
  grammarCheckId: string;
  starredAt: Date;
};

export function formatDocumentToModel({ document }: { document: any }): StarredGrammarCheck {
  return {
    userId: document.userId,
    grammarCheckId: document.grammarCheckId.toString(),
    starredAt: document.starredAt,
  };
}
