/**
 * Les ancres de la page d'accueil, en un seul endroit.
 *
 * Elles étaient écrites à la main dans trois fichiers — l'en-tête, le pied de
 * page et la page elle-même. Une ancre morte ne casse rien de visible : le
 * lien ne fait simplement rien, et personne ne s'en aperçoit avant des mois.
 * Écrites ici, c'est le compilateur qui remarque avant nous.
 */
export const SECTION = {
  tools: 'cong-cu',
  noAi: 'khong-ai',
  source: 'nguon',
  typography: 'hai-mat-chu',
  checklist: 'cau-hoi',
} as const

export type SectionId = (typeof SECTION)[keyof typeof SECTION]

export function anchor(id: SectionId) {
  return `#${id}`
}

/**
 * L'en-tête est collant sur 4rem : sans cette marge, cliquer une ancre range
 * le titre de la section juste derrière la barre.
 */
export const ANCHOR_OFFSET = 'scroll-mt-16'
