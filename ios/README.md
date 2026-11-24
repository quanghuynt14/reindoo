# reindoo pour iOS

Le dictionnaire, hors ligne. Swift et SwiftUI, construit à la manière de
Shopify (Reflex) : la logique vit dans Core, sans interface, et se teste en
millisecondes. La méthode est dans le skill `mobile:native-ios`.

```
ios/
  Core/         paquet Swift : écrans (ViewModels), navigation, lexique, historique, révision, file d'envoi
    Sources/ReindooCore/   aucune importation de SwiftUI ni d'UIKit
    Sources/reindoo-cli/   le CLI : `ls`, `do <action> [json]`, `build-lexicon`
    Tests/                 tests de comportement, par le protocole du CLI
  App/          vues SwiftUI. Elles lisent `state` et appellent `send`. Rien d'autre.
  project.yml   XcodeGen. Le .xcodeproj est généré.
```

## Travailler sur Core (Linux ou macOS)

```sh
swift test --package-path ios/Core
swift run  --package-path ios/Core reindoo-cli ls
swift run  --package-path ios/Core reindoo-cli 'do setQuery {"text":"allions"} ; do submit'
swift run  --package-path ios/Core reindoo-cli --fixture returning 'do selectTab {"name":"review"}'
```

Sans argument, le CLI lit des commandes sur l'entrée standard et garde son état.

## Construire l'app (macOS)

```sh
brew install xcodegen
cd ios && xcodegen generate && open Reindoo.xcodeproj
```

Deux schémas : `Reindoo` et `ReindooHan` (voir plus bas). Chacun lit son lexique dans son dossier de ressources.

Sans Mac : lancer le workflow « iOS » à la main sur GitHub. Il construit l'app
et dépose les captures d'écran, claires et sombres, en artefact.

Arguments de lancement (Debug) : `-fixture sample|returning`, `-tab search|review|history`,
`-query <texte>`, `-open <mot>`.

## Les décors du reel

Le reel peut porter un décor animé : vingt scènes reprises de `theme-examples`
(Anthropic, Apache 2.0), plus Aurora Snow. Core les construit et les évalue à
tout instant (`Scenery/`) ; l'app ne fait que les peindre dans un `Canvas`.

```sh
swift run --package-path ios/Core reindoo-cli scene snow-pines 390 844 12 > frame.svg   # une image, en SVG
swift run --package-path ios/Core reindoo-cli scene snow-pines original 12 > orig.svg     # la mise en page d'origine
swift run --package-path ios/Core reindoo-cli plan                                         # ce que chaque décor coûte par image
```

La version `original` de chaque décor se compare pixel à pixel au SVG du
greffon, mis en pause au même instant dans un navigateur. Les mises en page
`portrait` se regardent à l'œil.

## Le lexique

L'app cherche `App/Resources/lexicon.sqlite` (ignoré par git). Absent, elle se
rabat sur l'échantillon de Core, une vingtaine de mots. Pour le vrai :

```sh
# dans le dépôt dictionnaire : make mongo LANG=fr && make mongo LANG=en && make mongo LANG=vi
swift run --package-path ios/Core -c release reindoo-cli build-lexicon \
  ios/App/Resources/lexicon.sqlite ../dictionnaire/build/mongo-fr.ndjson ../dictionnaire/build/mongo-en.ndjson \
  ../dictionnaire/build/mongo-vi.ndjson
```

C'est le même NDJSON que `seedLexicon.ts` charge dans Mongo : le site et l'app
ne peuvent pas diverger.

Pháp–Việt et Anh–Việt pèsent 59 Mo pour 165 430 entrées et 446 469 formes ;
Việt–Pháp ajoute 16,7 Mo pour 32 717 entrées et 28 165 formes. Chaque entrée y
est rangée au plus court (`Packed.swift`) : ni le mot, ni la langue, ni
l'adresse du Wiktionnaire, qui se déduisent tous trois.

## Việt–Pháp

Le troisième dictionnaire va dans l'autre sens : un mot vietnamien, expliqué
en français. Les sens viennent du Wiktionnaire français ; là où il se tait ou
date, de l'anglais, tel quel et marqué [EN]. Le Wiktionnaire n'est pas
traduit automatiquement.

Les 1 000 mots les plus fréquents ont en plus une entrée reindoo, sous le
titre « Reindoo » et avant les sens du Wiktionnaire. Elle donne des
équivalents français, des étiquettes, des exemples et une note par sens.
Claude Opus l'a rédigée à partir des Wiktionnaires et de vraies phrases ; elle
n'a pas encore été relue par un humain. Dans le lexique, un sens reindoo porte
`r: true`, et sa note `o` (`Packed.swift`). Les sens du Wiktionnaire suivent
sous leur propre titre, et leurs numéros repartent de 1. Un mot sans entrée
reindoo n'a pas de titre.

La recherche y suit une règle à part (`Language.isOftenTypedBare`) :

- tapé **sans accents**, un mot ouvre sa lecture la plus fréquente, les autres
  à côté : « an » ouvre « ăn », avec an, án, ấn… Même quand « an » existe tel
  quel ;
- tapé **avec** un accent, il n'est jamais replié : « ẳn » n'ouvre pas « ăn »,
  il le propose ;
- « đ » se replie en « d » : « dep » ouvre « đẹp ».

## Les notes pour retenir

Un mot qui a une histoire porte une note : d'où il vient, ses mots voisins, un
mémo. Elle s'écrit dans `dictionnaire`, `data/memo-<langue>.jsonl`, en
vietnamien, une ligne par mot, marquée `"by": "huy"`. L'outil MCP `dico_meo`
l'y écrit depuis une conversation. Un mot courant n'en a pas : pas de note,
pas de bouton.

Dans l'app, un cerveau se pose à côté du cœur, dans l'entrée et dans le reel,
et ouvre la note en feuille (`MemoView`). Dans le reel, sens d'abord, il attend
que le mot paraisse : la note le donnerait.

## Reindoo Hán

Une deuxième app, du même code : le chinois expliqué en vietnamien, le
vietnamien expliqué en chinois. Cible XcodeGen `ReindooHan`, identifiant
`com.reindoo.han`, nom « Reindoo Hán ».

- **L'édition** (`Edition.swift`) choisit les langues offertes, dans l'ordre
  du sélecteur, et le petit lexique de secours. L'app la lit dans la clé
  `ReindooEdition` de son Info.plist (`Han/Info.plist`, la seule clé qu'il
  porte ; Xcode génère le reste). Sans clé : reindoo. Le CLI prend
  `--edition han`.
- Une langue que le lexique ne sert pas n'est pas offerte : sans le fichier
  Việt–Trung, Hán ne propose que le chinois.
- **Le chinois se cherche** en caractères, simplifiés ou traditionnels (les
  formes du NDJSON), et en pinyin : avec tons, avec chiffres, sans tons,
  sans espaces, ü tapé v ou u. Le constructeur range chaque lecture sous deux
  clés de la table des formes (`Text.pinyinKey`, `Text.toneKey`). Un ton
  tapé est un choix : « shí » ouvre 十, « shi » ouvre le plus courant, 是.
- Le NDJSON chinois (`make mongo LANG=zh`, branche `han` de dictionnaire)
  porte le pinyin dans `ipa`, la lecture Hán Việt dans `hanviet`, la graphie
  traditionnelle dans `traditional`, et la lecture de chaque exemple dans
  `pinyin`. L'entrée montre les trois sous le mot. `variants` n'est pas lu :
  ces graphies sont déjà des formes. Les noms de champs sont reliés à l'app
  en un seul endroit, `LexiconBuilder.Line`.
- L'adresse Wiktionary d'un mot chinois se déduit quand elle vise la section
  « Chinese » du Wiktionnaire anglais (95 % des mots) ; celles du
  Wiktionnaire vietnamien se gardent en entier.
- Le lexique va dans `Han/Resources/lexicon.sqlite` (ignoré par git),
  l'icône dans `Han/Assets.xcassets`, fabriquée par
  `python3 ios/scripts/han-icon.py` à partir de celle de reindoo.

```sh
# dans dictionnaire, branche han : python3 scripts/fetch.py --lang zh && make mongo LANG=zh
swift run --package-path ios/Core -c release reindoo-cli build-lexicon \
  ios/Han/Resources/lexicon.sqlite ../dictionnaire/build/mongo-zh.ndjson
swift run --package-path ios/Core reindoo-cli --edition han 'do setQuery {"text":"nihao"} ; do submit'
```

En CI, le job `lexicon-han` suit la branche `DICTIONNAIRE_HAN_BRANCH`
(variable du dépôt, `han` par défaut) et les LANG de `DICTIONNAIRE_HAN_LANGS`
(`zh` par défaut ; ajouter celui du Việt–Trung, séparé par une espace). Une
étiquette `han-vX.Y.Z` envoie Reindoo Hán sur TestFlight, avec les mêmes
secrets ; la fiche `com.reindoo.han` doit exister dans App Store Connect.

## Règles

- Ce que l'utilisateur voit est dans `state`. Ce qu'il peut faire est une `Action`.
- `send` est le seul endroit où l'état change.
- L'historique garde (langue, mot), jamais un identifiant du lexique.
- L'interface parle anglais, français et vietnamien. Tout le texte vient de `Copy.swift` et passe par l'état des écrans : une vue n'écrit aucun mot. La langue suit celle que le système donne à l'app.
- Pas de liste de favoris : l'app garde l'historique, et le reel (« Lướt ôn ») le fait réviser.
- Le reel ne finit pas. Un cœur fait revenir un mot deux fois par tour. Entre les mots viennent des
  surprises : une question, un mot nouveau, le compte de la série. Leur tirage passe par `chance`,
  que les fixtures remplacent : les tests ne doivent rien au hasard.
- Un mot se balaie de côté, sens montré ou non. Vers la gauche, « je sais » : il saute les deux tours
  suivants et revient au troisième. Vers la droite, « à revoir » : il passe deux fois par tour jusqu'à
  ce qu'on le sache. Le geste passe à la carte suivante. Le numéro du tour survit au lancement.
  Chaque geste compte aussi pour FSRS (`Memory.swift`) et le journal `recall`, qui restent sur
  l'appareil : le serveur ne les connaît pas encore.
- Chaque écriture locale pose son changement dans la file, dans la même transaction.
- Un comportement nouveau arrive avec son test, cas d'échec compris.

## TestFlight

Pousser une étiquette `ios-vX.Y.Z` archive l'app, la signe et l'envoie :

```sh
git tag ios-v0.1.0 && git push origin ios-v0.1.0
```

Le numéro de version vient de l'étiquette, le numéro de build du numéro
d'exécution du workflow. La signature est automatique, avec une clé d'API
App Store Connect. Quatre secrets du dépôt : `APPLE_TEAM_ID`, `ASC_KEY_ID`,
`ASC_ISSUER_ID`, `ASC_KEY_P8` (le contenu du fichier `.p8`). La fiche de l'app
doit exister dans App Store Connect, avec l'identifiant `com.reindoo.app`.

## Ce qui n'existe pas encore

- La synchronisation avec le serveur. La file d'envoi et sa boucle sont là et
  testées contre un faux serveur ; il manque le client HTTP, la connexion
  (better-auth par jeton), et des routes serveur qui acceptent (langue, mot).
- Vérification grammaticale, traduction, jeu, reels.
- Audio de prononciation.
