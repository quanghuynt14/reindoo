export const LANGUAGE = {
  ENGLISH: 'english',
  FRENCH: 'french',
  VIETNAMESE: 'vietnamese',
  SPANISH: 'spanish',
  GERMAN: 'german',
} as const;

/**
 * Les couples que le dictionnaire sert, et les seuls.
 *
 * Chacun a un lexique compilé derrière lui — 45 987 vedettes françaises,
 * 119 091 anglaises, glosées en vietnamien. Les autres n'en ont pas et n'en
 * auront pas : c'était l'affaire du modèle de langue, qui répondait sur
 * n'importe quel couple parce qu'il inventait.
 *
 * La base gardait des restes de cette époque — de l'allemand, de l'espagnol,
 * du vietnamien vers autre chose. Ils ont été enlevés ; cette liste est ce qui
 * les empêche de revenir.
 */
export const DICTIONARY_SOURCE_LANGUAGES = [
  LANGUAGE.FRENCH,
  LANGUAGE.ENGLISH,
] as const;

export const DICTIONARY_TARGET_LANGUAGE = LANGUAGE.VIETNAMESE;

