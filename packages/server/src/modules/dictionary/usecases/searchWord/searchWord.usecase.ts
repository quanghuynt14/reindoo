import type { Language, Word } from '@practice/shared';
import type { createDictionaryRepository } from '../../_storage/dictionary.repository.ts';
import type { createSearchHistoryRepository } from '../../_storage/searchHistory.repository.ts';

/**
 * Chercher un mot, c'est lire le lexique. Rien d'autre.
 *
 * Ce cas d'usage appelait un modèle de langue quand le mot n'était pas en base,
 * et écrivait la réponse dans la même collection que le reste. Trois raisons de
 * l'avoir retiré :
 *
 *   - un modèle qui ne connaît pas un mot en invente un, et rien dans la page
 *     ne distinguait ensuite une glose inventée d'une glose lue ;
 *   - le contenu du site et celui du bundle Dictionary.app divergeaient, alors
 *     qu'ils sont censés être le même dictionnaire ;
 *   - une recherche coûtait une requête réseau et un jeton d'API.
 *
 * Le lexique vient maintenant du dépôt `dictionnaire`, chargé par
 * `scripts/seedLexicon.ts`. Il est fini, et c'est le but : un mot absent est
 * dit absent, avec des propositions, plutôt que rempli par une supposition.
 */

/** Distance de Levenshtein bornée : au-delà de `max`, on rend `max + 1`.
 *
 * Bornée parce qu'elle sert à classer des propositions, pas à mesurer : dès
 * qu'une ligne entière dépasse le seuil, aucune suite ne peut redescendre, et
 * on s'arrête. Sur quelques milliers de candidats la différence est nette.
 */
function editDistance(a: string, b: string, max: number): number {
  if (Math.abs(a.length - b.length) > max) return max + 1;

  let previous = Array.from({ length: b.length + 1 }, (_, i) => i);

  for (let i = 1; i <= a.length; i++) {
    const current = [i];
    let best = i;
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      const value = Math.min(
        current[j - 1]! + 1,
        previous[j]! + 1,
        previous[j - 1]! + cost,
      );
      current.push(value);
      if (value < best) best = value;
    }
    if (best > max) return max + 1;
    previous = current;
  }

  return previous[b.length]!;
}

/**
 * Champs déclarés puis affectés, et non des propriétés de paramètre : le
 * tsconfig du dépôt pose `erasableSyntaxOnly`, qui interdit `constructor(public
 * readonly x)` — cette forme-là émet du code, et le projet veut du TypeScript
 * qu'on puisse effacer pour obtenir du JavaScript valide.
 */
export class WordNotFoundError extends Error {
  readonly searchingWord: string;
  readonly suggestions: string[];

  constructor(searchingWord: string, suggestions: string[]) {
    super(`Không tìm thấy từ "${searchingWord}"`);
    this.name = 'WordNotFoundError';
    this.searchingWord = searchingWord;
    this.suggestions = suggestions;
  }
}

export function createSearchWordUsecase({
  dictionaryRepository,
  searchHistoryRepository,
}: {
  dictionaryRepository: ReturnType<typeof createDictionaryRepository>;
  searchHistoryRepository: ReturnType<typeof createSearchHistoryRepository>;
}) {
  return async ({
    userId,
    searchingWord,
    sourceLanguage,
    targetLanguage,
    saveToHistory = true,
  }: {
    userId: string;
    searchingWord: string;
    sourceLanguage: Language;
    targetLanguage: Language;
    saveToHistory?: boolean;
  }): Promise<Word> => {
    const remember = async (word: Word) => {
      if (saveToHistory) {
        await searchHistoryRepository.addSearchHistory({ userId, wordId: word.id });
      }
      return word;
    };

    // Ce que le mot tapé est aussi une flexion de. Consulté dans les deux cas,
    // et pas seulement quand la recherche directe échoue.
    //
    // Le Wiktionnaire vietnamien donne à « went » sa propre entrée, dont la
    // glose entière est « động từ quá khứ của go » — un renvoi, pas un sens.
    // La recherche directe la trouvait, s'arrêtait là, et le lecteur repartait
    // sans savoir ce que « go » veut dire. C'est le même problème que le bundle
    // règle avec ses pages de forme ambiguë, et il se règle ici pareil : on
    // rattache les deux.
    const lemmas = await dictionaryRepository.findLemmasForForm({
      form: searchingWord,
      sourceLanguage,
    });

    // 1. La vedette elle-même.
    const direct = await dictionaryRepository.findOne({
      searchingWord,
      sourceLanguage,
      targetLanguage,
    });
    if (direct) {
      const others = lemmas.filter((lemma) => lemma !== direct.word);
      return remember(others.length > 0 ? { ...direct, alsoFrom: others } : direct);
    }

    // 2. Une forme fléchie. C'est ce que le site ne savait pas faire : « allions »
    //    n'y donnait rien, alors que le bundle Apple le résout depuis Verbiste.
    //    Une forme peut mener à plusieurs mots — « allions » est de *aller* et
    //    de *allier* — et on rend le plus fréquent, en nommant les autres.
    if (lemmas.length > 0) {
      const words = await dictionaryRepository.findManyByWords({
        words: lemmas,
        sourceLanguage,
        targetLanguage,
      });
      const [best] = words;
      if (best) {
        return remember({
          ...best,
          matchedForm: searchingWord,
          alsoFrom: words.slice(1).map((w) => w.word),
        });
      }
    }

    // 3. Rien. On le dit, avec de quoi rebondir — c'est le prix honnête de
    //    n'avoir plus de modèle pour combler les trous.
    const candidates = await dictionaryRepository.findNeighbours({
      searchingWord,
      sourceLanguage,
      targetLanguage,
    });

    const suggestions = candidates
      .map((word) => ({ word, d: editDistance(searchingWord, word, 3) }))
      .filter(({ d }) => d <= 3)
      .sort((a, b) => a.d - b.d)
      .slice(0, 8)
      .map(({ word }) => word);

    throw new WordNotFoundError(searchingWord, suggestions);
  };
}
