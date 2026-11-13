/**
 * Le lexique chargé en base répond-il ?
 *
 *   node --env-file deploy/.env.production packages/server/src/scripts/checkLexicon.ts
 *
 * Pendant qu'un chargement tourne, les compteurs montent : c'est normal, et
 * c'est la première chose que ce script dit. Une fois qu'il est fini, ils
 * doivent tomber *exactement* sur les totaux attendus — un document en moins
 * est un mot qu'on ne trouvera jamais, et rien d'autre ne le signalerait.
 *
 * Les totaux viennent de la sortie de `emit_mongo.py`, qui les imprime à chaque
 * génération. Les mettre à jour ici quand la source bouge.
 */

import process from 'node:process';
import { MongoClient } from 'mongodb';

const EXPECTED: Record<string, { words: number, forms: number }> = {
  french: { words: 46_160, forms: 246_588 },
  english: { words: 119_108, forms: 199_674 },
};

// Ce qu'un dictionnaire doit savoir faire, et que le seul comptage ne dit pas.
const PROBES: Record<string, string[]> = {
  french: ['aller', 'allions', 'prises', 'chats', 'vécu', 'éblouissement',
           // Le pronominal : « se plaindre » n'est pas « plaindre ».
           'se plaindre', 'se défendre', "s'habiller"],
  english: ['go', 'went', 'saw', 'children', 'running', 'book'],
};

async function main() {
  const url = process.env['MONGODB_URL'];
  if (!url) throw new Error('MONGODB_URL manquant');

  const client = new MongoClient(url, { serverSelectionTimeoutMS: 15000 });
  await client.connect();
  const db = client.db(process.env['MONGODB_DB_NAME'] || 'practice');

  const words = db.collection('dictionary');
  const forms = db.collection('dictionary_forms');

  const languages = await words.distinct('sourceLanguage');
  let allGood = true;

  console.log(`base : ${db.databaseName}\n`);

  for (const language of languages) {
    const nWords = await words.countDocuments({ sourceLanguage: language });
    const nForms = await forms.countDocuments({ sourceLanguage: language });
    const want = EXPECTED[language as string];

    if (!want) {
      console.log(`  ${String(language).padEnd(9)} ${nWords.toLocaleString()} mots, ` +
        `${nForms.toLocaleString()} formes   (langue non attendue — restes d'avant ?)`);
      continue;
    }

    const okWords = nWords === want.words;
    const okForms = nForms === want.forms;
    if (!okWords || !okForms) allGood = false;

    const fmt = (got: number, expect: number, ok: boolean) =>
      ok ? `${got.toLocaleString()}` : `${got.toLocaleString()} / ${expect.toLocaleString()} attendus`;

    console.log(`  ${okWords && okForms ? '✓' : '✗'} ${String(language).padEnd(9)} ` +
      `mots ${fmt(nWords, want.words, okWords).padEnd(24)} ` +
      `formes ${fmt(nForms, want.forms, okForms)}`);
  }

  // Les index. Sans eux la recherche marche et s'écroule : c'est le genre de
  // panne qui n'apparaît qu'en production, sous charge.
  //
  // Par motif de clés et non par nom : un index créé sans nom s'appelle
  // « word_1_sourceLanguage_1_targetLanguage_1 » et fait le même travail que
  // celui qu'on aurait nommé « lookup ». Chercher le nom disait « manquant »
  // sur un index parfaitement en place.
  const hasKeys = (indexes: { key: object }[], keys: object) =>
    indexes.some((index) => JSON.stringify(index.key) === JSON.stringify(keys));

  const wordIndexes = await words.indexes();
  const formIndexes = await forms.indexes();
  const missing = [
    !hasKeys(wordIndexes, { word: 1, sourceLanguage: 1, targetLanguage: 1 })
      && 'dictionary { word, sourceLanguage, targetLanguage }',
    !hasKeys(formIndexes, { form: 1, sourceLanguage: 1 })
      && 'dictionary_forms { form, sourceLanguage }',
  ].filter(Boolean);
  console.log(`\n  index : ${[...wordIndexes, ...formIndexes].map((i) => i.name).join(', ')}`);
  if (missing.length > 0) {
    allGood = false;
    console.log(`  ✗ index manquants : ${missing.join(', ')}`);
  }

  // Le canari. Chaque document chargé porte le buildId de son chargement ; un
  // document sans buildId a donc été écrit par autre chose que le seeder — et
  // la seule chose qui écrivait dans cette collection était le modèle de
  // langue, du temps où une recherche infructueuse fabriquait son entrée.
  //
  // Zéro veut dire que le serveur déployé lit le lexique et n'invente rien.
  // Ça ne prouve pas que le déploiement est à jour — personne n'a peut-être
  // encore cherché un mot absent — mais dès que ça dépasse zéro, c'est du texte
  // généré posé dans le dictionnaire, et plus rien ne l'y distinguera.
  const stray = await words.countDocuments({ buildId: { $exists: false } });
  if (stray > 0) {
    allGood = false;
    console.log(`\n  ✗ ${stray.toLocaleString()} document(s) écrits hors du seeder`);
    const sample = await words
      .find({ buildId: { $exists: false } }, { projection: { word: 1, sourceLanguage: 1 } })
      .limit(5).toArray();
    for (const document of sample) {
      console.log(`      ${String(document['word'])} (${String(document['sourceLanguage'])})`);
    }
    console.log('      Le serveur déployé écrit encore : vérifiez qu\'il tourne');
    console.log('      la version où searchWord ne fait plus que lire.');
  }
  else {
    console.log('\n  ✓ rien d\'écrit hors du seeder');
  }

  // Et la seule question qui compte vraiment : est-ce qu'on trouve les mots ?
  for (const language of languages) {
    const probes = PROBES[language as string];
    if (!probes) continue;
    console.log(`\n  ${language} :`);
    for (const probe of probes) {
      const direct = await words.findOne(
        { word: probe, sourceLanguage: language },
        { projection: { word: 1, translated: 1 } },
      );
      const viaForm = await forms.findOne(
        { form: probe, sourceLanguage: language },
        { projection: { lemmas: 1 } },
      );
      if (!direct && !viaForm) {
        allGood = false;
        console.log(`    ✗ ${probe.padEnd(16)} introuvable`);
        continue;
      }
      const target = direct?.['translated'] as string | undefined;
      const also = (viaForm?.['lemmas'] as string[] | undefined)?.filter((l) => l !== probe);
      console.log(`    ✓ ${probe.padEnd(16)} ${(target ?? '—').slice(0, 40).padEnd(42)}` +
        `${also?.length ? `aussi : ${also.join(', ')}` : ''}`);
    }
  }

  await client.close();
  if (!allGood) {
    console.log('\n  ✗ le lexique est incomplet — relancez seedLexicon.ts pour la langue en cause');
    process.exit(1);
  }
  console.log('\n  ✓ le lexique répond');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
