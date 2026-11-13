/**
 * Charge le lexique compilé par le dépôt `dictionnaire` dans Mongo.
 *
 *   node --env-file deploy/.env.production \
 *     packages/server/src/scripts/seedLexicon.ts ../dictionnaire/build/mongo-fr.ndjson
 *
 * Le fichier vient de `make mongo LANG=fr`, et il porte le même contenu que le
 * bundle Dictionary.app : les deux sortent du même lexicon.jsonl. C'est la
 * raison d'être de ce découpage — le site et la fenêtre de survol ne peuvent
 * pas diverger.
 *
 * ## On écrit avant d'effacer, jamais l'inverse
 *
 * La première version effaçait la langue puis rechargeait. Un Ctrl-C au milieu
 * laissait alors un dictionnaire à moitié plein : pas une erreur, pas une
 * panne visible — juste « không tìm thấy » sur tous les mots pas encore
 * écrits. Contre une base de production, c'est une mauvaise réponse rendue en
 * silence, ce qui est pire qu'une coupure.
 *
 * Chaque chargement porte donc un `buildId`, et l'ordre est :
 *
 *   1. poser les index — avant, pour qu'une interruption les laisse en place ;
 *   2. écrire tous les documents, marqués du buildId courant ;
 *   3. **puis** effacer, en une opération, ce qui porte un autre buildId.
 *
 * Interrompu avant l'étape 3, on a l'ancien *et* le nouveau : des doublons,
 * donc une réponse peut être périmée pendant quelques minutes — mais jamais un
 * trou. Et relancer nettoie : le nouveau buildId balaie tout le reste, y
 * compris les orphelins d'une tentative avortée.
 *
 * Ce qu'il ne touche pas : `searchHistory` et `starredWords`. Ils pointent des
 * `_id` de `dictionary`, et c'est pour ça que la collection garde sa forme au
 * lieu d'être refaite à côté. Les `_id` changent quand même à chaque
 * chargement complet — voir `--keep-ids`.
 */

import type { AnyBulkWriteOperation, Document } from 'mongodb';
import { createInterface } from 'node:readline';
import { createReadStream } from 'node:fs';
import { randomUUID } from 'node:crypto';
import process from 'node:process';
import { MongoClient } from 'mongodb';

const BATCH = 2000;

type Row = Document & { _collection: string };

async function main() {
  const [file, ...flags] = process.argv.slice(2);
  if (!file) {
    console.error('usage: seedLexicon.ts <mongo-LL.ndjson> [--keep-ids]');
    process.exit(1);
  }
  // Par défaut on réécrit tout, ce qui réattribue les `_id` — donc casse les
  // renvois de l'historique et des favoris. `--keep-ids` met à jour en place :
  // beaucoup plus lent, mais l'historique survit. Le balayage final par
  // buildId est le même dans les deux cas.
  const keepIds = flags.includes('--keep-ids');
  const buildId = `${new Date().toISOString()}-${randomUUID().slice(0, 8)}`;

  const url = process.env['MONGODB_URL'];
  if (!url) throw new Error('MONGODB_URL manquant');

  const client = new MongoClient(url, { serverSelectionTimeoutMS: 15000 });
  await client.connect();
  const db = client.db(process.env['MONGODB_DB_NAME'] || 'practice');

  const words = db.collection('dictionary');
  const forms = db.collection('dictionary_forms');

  // 1. Les index d'abord. Sans eux, chaque recherche balaie 165 000 documents ;
  //    et les poser avant plutôt qu'après veut dire qu'une interruption les
  //    laisse en place.
  //
  //    On compare par **motif de clés**, jamais par nom. `createIndex` avec un
  //    nom explicite échoue en code 85 quand les mêmes clés existent déjà sous
  //    un autre nom — ce qui est exactement le cas en production, où l'index
  //    s'appelle `word_1_sourceLanguage_1_targetLanguage_1` parce qu'il a été
  //    créé sans nom. Une base de test fraîche ne montre jamais ça.
  const ensureIndex = async (
    collection: typeof words,
    keys: Record<string, 1 | -1>,
  ) => {
    const wanted = JSON.stringify(keys);
    const existing = await collection.indexes();
    if (existing.some((index) => JSON.stringify(index.key) === wanted)) return;
    await collection.createIndex(keys);
  };

  await ensureIndex(words, { word: 1, sourceLanguage: 1, targetLanguage: 1 });
  await ensureIndex(words, { rank: -1 });
  await ensureIndex(words, { sourceLanguage: 1, buildId: 1 });
  await ensureIndex(forms, { form: 1, sourceLanguage: 1 });
  await ensureIndex(forms, { sourceLanguage: 1, buildId: 1 });

  const buffers = new Map<string, AnyBulkWriteOperation[]>();
  const counts = new Map<string, number>();
  let language: string | null = null;

  const flush = async (name: string, force = false) => {
    const ops = buffers.get(name);
    if (!ops || ops.length === 0 || (!force && ops.length < BATCH)) return;
    await db.collection(name).bulkWrite(ops, { ordered: false });
    counts.set(name, (counts.get(name) ?? 0) + ops.length);
    buffers.set(name, []);
  };

  console.log(`  build ${buildId}`);

  const rl = createInterface({
    input: createReadStream(file, { encoding: 'utf8' }),
    crlfDelay: Infinity,
  });

  // 2. Écrire.
  for await (const line of rl) {
    if (!line.trim()) continue;
    const { _collection: name, ...rest } = JSON.parse(line) as Row;
    const doc: Document = { ...rest, buildId };
    language ??= String(doc['sourceLanguage']);

    const op: AnyBulkWriteOperation = keepIds
      ? {
          updateOne: {
            filter: name === 'dictionary'
              ? {
                  word: doc['word'],
                  sourceLanguage: doc['sourceLanguage'],
                  targetLanguage: doc['targetLanguage'],
                }
              : { form: doc['form'], sourceLanguage: doc['sourceLanguage'] },
            update: { $set: doc },
            upsert: true,
          },
        }
      : { insertOne: { document: doc } };

    const ops = buffers.get(name) ?? [];
    ops.push(op);
    buffers.set(name, ops);
    await flush(name);
  }

  for (const name of buffers.keys()) await flush(name, true);

  if (!language) throw new Error(`${file} est vide — rien n'a été touché`);

  for (const [name, n] of counts) console.log(`  ${name.padEnd(18)} ${n.toLocaleString()} écrits`);

  // 3. Et seulement maintenant, effacer. Une opération par collection, sur un
  //    index dédié — c'est la seule fenêtre où la base est inconsistante, et
  //    elle dure le temps d'un deleteMany.
  //
  //    `$ne` répond vrai quand le champ est absent : les documents d'avant la
  //    bascule, qui n'ont pas de buildId, partent avec les autres.
  const stale = { sourceLanguage: language, buildId: { $ne: buildId } };
  const removedWords = await words.deleteMany(stale);
  const removedForms = await forms.deleteMany(stale);

  console.log(`  ${removedWords.deletedCount.toLocaleString()} mots et ` +
    `${removedForms.deletedCount.toLocaleString()} formes périmés effacés`);
  console.log(`  langue : ${language}`);

  await client.close();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
