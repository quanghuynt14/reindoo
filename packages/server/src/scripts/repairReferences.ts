/**
 * Historique et favoris qui pointent un mot disparu.
 *
 *   node --env-file deploy/.env.production \
 *     packages/server/src/scripts/repairReferences.ts            # compte
 *   node ... repairReferences.ts --prune                          # efface
 *
 * ## D'où viennent ces références mortes
 *
 * `searchHistory` et `starredWords` ne gardent qu'un `wordId` — un `_id` de
 * `dictionary`. Recharger le lexique sans `--keep-ids` réattribue tous ces
 * `_id` : les anciennes références ne résolvent plus.
 *
 * **Et elles ne sont pas réparables.** Aucune des deux collections ne garde le
 * mot lui-même, seulement son identifiant. Le document disparu emporte la seule
 * chose qui aurait permis de le retrouver. Ce script ne répare donc rien : il
 * compte, et il enlève. Le nom est optimiste.
 *
 * La prévention, elle, existe : `seedLexicon.ts --keep-ids` met à jour en place
 * au lieu de réécrire, et les `_id` survivent.
 *
 * ## Les langues qu'on ne sert pas
 *
 * `--prune` enlève aussi les entrées d'un couple qu'on ne sert pas. La base en
 * gardait des restes de l'époque où un modèle répondait sur n'importe quelle
 * langue : de l'allemand, de l'espagnol, du vietnamien-vers-autre-chose. Ces
 * entrées n'ont pas de lexique derrière elles et n'en auront pas.
 *
 * L'ordre compte : on enlève les entrées d'abord, les références ensuite. Sinon
 * les références qui les visaient survivraient au passage et deviendraient
 * mortes juste après.
 */

import process from 'node:process';
import { MongoClient } from 'mongodb';

type Target = { name: string, label: string };

const TARGETS: Target[] = [
  { name: 'searchHistory', label: 'historique' },
  { name: 'starredWords', label: 'favoris' },
];

// Les seuls couples servis. Tout le reste est un reste.
const SOURCES = ['french', 'english'];
const TARGET = 'vietnamese';

async function main() {
  const prune = process.argv.includes('--prune');

  const url = process.env['MONGODB_URL'];
  if (!url) throw new Error('MONGODB_URL manquant');

  const client = new MongoClient(url, { serverSelectionTimeoutMS: 15000 });
  await client.connect();
  const db = client.db(process.env['MONGODB_DB_NAME'] || 'practice');

  console.log(`base : ${db.databaseName}${prune ? '' : '   (comptage seul — --prune pour effacer)'}\n`);

  // 1. Les entrées d'un couple qu'on ne sert pas. Avant les références, pour
  //    que celles qui les visaient soient comptées mortes dans la foulée.
  const unsupported = {
    $or: [
      { sourceLanguage: { $nin: SOURCES } },
      { targetLanguage: { $exists: true, $ne: TARGET } },
    ],
  };

  const strays = await db.collection('dictionary').aggregate([
    { $match: unsupported },
    { $group: { _id: { source: '$sourceLanguage', target: '$targetLanguage' }, n: { $sum: 1 } } },
    { $sort: { n: -1 } },
  ]).toArray();

  if (strays.length > 0) {
    console.log('  couples non servis :');
    for (const stray of strays) {
      const key = stray['_id'] as { source?: string, target?: string };
      console.log(`      ${String(key.source ?? '?')} → ${String(key.target ?? '?')}`.padEnd(34) +
        `${(stray['n'] as number).toLocaleString()}`);
    }
    if (prune) {
      const words = await db.collection('dictionary').deleteMany(unsupported);
      const forms = await db.collection('dictionary_forms').deleteMany({
        sourceLanguage: { $nin: SOURCES },
      });
      console.log(`      → ${words.deletedCount.toLocaleString()} entrées et ` +
        `${forms.deletedCount.toLocaleString()} formes effacées`);
    }
    console.log('');
  }

  let total = 0;

  for (const { name, label } of TARGETS) {
    const collection = db.collection(name);
    const all = await collection.countDocuments();

    // Un $lookup plutôt qu'une requête par ligne : sur un historique de
    // plusieurs milliers d'entrées, la seconde forme fait autant d'allers-
    // retours vers Atlas, et chacun coûte sa latence réseau.
    const orphans = await collection.aggregate([
      {
        $lookup: {
          from: 'dictionary',
          localField: 'wordId',
          foreignField: '_id',
          as: 'word',
        },
      },
      { $match: { word: { $size: 0 } } },
      { $project: { _id: 1, userId: 1 } },
    ]).toArray();

    total += orphans.length;
    const share = all > 0 ? Math.round((orphans.length / all) * 100) : 0;
    console.log(`  ${label.padEnd(12)} ${orphans.length.toLocaleString()} morte(s) ` +
      `sur ${all.toLocaleString()} (${share} %)`);

    // Par utilisateur : c'est ce qui dit si la perte est répartie ou si elle
    // tombe sur une seule personne.
    const byUser = new Map<string, number>();
    for (const orphan of orphans) {
      const user = String(orphan['userId'] ?? '?');
      byUser.set(user, (byUser.get(user) ?? 0) + 1);
    }
    for (const [user, n] of [...byUser].sort((a, b) => b[1] - a[1]).slice(0, 5)) {
      console.log(`      ${user.slice(0, 24).padEnd(26)} ${n.toLocaleString()}`);
    }

    if (prune && orphans.length > 0) {
      const result = await collection.deleteMany({
        _id: { $in: orphans.map((o) => o['_id']) },
      });
      console.log(`      → ${result.deletedCount.toLocaleString()} effacée(s)`);
    }
  }

  if (total === 0) {
    console.log('\n  ✓ aucune référence morte');
  }
  else if (!prune) {
    console.log(`\n  ${total.toLocaleString()} au total. Elles ne sont pas récupérables :`);
    console.log('  ni l\'historique ni les favoris ne gardent le mot, seulement son id.');
    console.log('  --prune pour les enlever. Pour ne pas en refabriquer :');
    console.log('  seedLexicon.ts --keep-ids');
  }

  await client.close();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
