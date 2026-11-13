import type { Language } from '@practice/shared';
import type { Db } from 'mongodb';
import { ObjectId } from 'mongodb';
import { getDictionaryCollection } from './dictionary.collection.ts';
import { formatDocumentToModel } from './dictionary.repository.model.ts';

export function createDictionaryRepository({ db }: { db: Db }) {
  const collection = getDictionaryCollection({ db });
  const formsCollection = db.collection('dictionary_forms');

  return {
    async getWordById({
      wordId,
    }: {
      wordId: string;
    }) {
      const document = await collection.findOne(
        { _id: new ObjectId(wordId) },
      );

      if (!document) {
        return undefined;
      }

      return formatDocumentToModel({ document });
    },

    async getWordsByIds({
      wordIds,
    }: {
      wordIds: string[];
    }) {
      const objectIds = wordIds
        .filter((id) => ObjectId.isValid(id))
        .map((id) => new ObjectId(id));

      if (objectIds.length === 0) {
        return wordIds.map(() => undefined);
      }

      const documents = await collection.find(
        { _id: { $in: objectIds } },
      ).toArray();

      const documentById = new Map<string, typeof documents[number]>();
      for (const document of documents) {
        documentById.set(document._id.toString(), document);
      }

      return wordIds.map((id) => {
        const document = documentById.get(id);
        if (!document) {
          return undefined;
        }
        return formatDocumentToModel({ document });
      });
    },

    async findOne({
      searchingWord,
      sourceLanguage,
      targetLanguage,
    }: {
      searchingWord: string;
      sourceLanguage: Language;
      targetLanguage: Language;
    }) {
      const document = await collection.findOne(
        { word: searchingWord, sourceLanguage, targetLanguage },
      );

      if (!document) {
        return undefined;
      }

      return formatDocumentToModel({ document });
    },

    /** Les vedettes qu'une forme fléchie atteint, la plus fréquente d'abord.
     *
     * C'est la moitié du dictionnaire. « allions » n'est pas une vedette ; il
     * mène à *aller* et à *allier*, et sans cette table le site répondait
     * « introuvable » à un mot parfaitement français.
     */
    async findLemmasForForm({
      form,
      sourceLanguage,
    }: {
      form: string;
      sourceLanguage: Language;
    }): Promise<string[]> {
      const document = await formsCollection.findOne({ form, sourceLanguage });
      return (document?.['lemmas'] as string[] | undefined) ?? [];
    },

    async findManyByWords({
      words,
      sourceLanguage,
      targetLanguage,
    }: {
      words: string[];
      sourceLanguage: Language;
      targetLanguage: Language;
    }) {
      if (words.length === 0) return [];

      const documents = await collection
        .find({ word: { $in: words }, sourceLanguage, targetLanguage })
        .sort({ rank: -1 })
        .toArray();

      return documents.map((document) => formatDocumentToModel({ document }));
    },

    /** Des vedettes proches, pour proposer quelque chose quand rien ne colle.
     *
     * On ne calcule pas la distance d'édition dans Mongo : il faudrait la
     * mesurer contre 165 000 documents. On présélectionne par préfixe — deux
     * ou trois premières lettres, ce qui attrape la faute de frappe ordinaire
     * — et le classement fin se fait en mémoire sur quelques centaines de mots.
     */
    async findNeighbours({
      searchingWord,
      sourceLanguage,
      targetLanguage,
    }: {
      searchingWord: string;
      sourceLanguage: Language;
      targetLanguage: Language;
    }): Promise<string[]> {
      const prefix = searchingWord.slice(0, Math.min(3, searchingWord.length));
      if (!prefix) return [];

      const escaped = prefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const documents = await collection
        .find(
          { sourceLanguage, targetLanguage, word: { $regex: `^${escaped}`, $options: 'i' } },
          { projection: { word: 1 }, limit: 400 },
        )
        .sort({ rank: -1 })
        .toArray();

      return documents.map((document) => document['word'] as string);
    },
  };
};
