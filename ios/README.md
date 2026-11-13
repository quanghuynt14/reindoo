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

Sans Mac : lancer le workflow « iOS » à la main sur GitHub. Il construit l'app
et dépose les captures d'écran, claires et sombres, en artefact.

Arguments de lancement (Debug) : `-fixture sample|returning`, `-tab search|review|history`,
`-query <texte>`, `-open <mot>`.

## Le lexique

L'app cherche `App/Resources/lexicon.sqlite` (ignoré par git). Absent, elle se
rabat sur l'échantillon de Core, une quinzaine de mots. Pour le vrai :

```sh
# dans le dépôt dictionnaire : make mongo LANG=fr && make mongo LANG=en
swift run --package-path ios/Core -c release reindoo-cli build-lexicon \
  ios/App/Resources/lexicon.sqlite ../dictionnaire/build/mongo-fr.ndjson ../dictionnaire/build/mongo-en.ndjson
```

C'est le même NDJSON que `seedLexicon.ts` charge dans Mongo : le site et l'app
ne peuvent pas diverger.

Le fichier pèse 59 Mo pour 165 430 entrées et 446 469 formes. Chaque entrée y
est rangée au plus court (`Packed.swift`) : ni le mot, ni la langue, ni
l'adresse du Wiktionnaire, qui se déduisent tous trois.

## Règles

- Ce que l'utilisateur voit est dans `state`. Ce qu'il peut faire est une `Action`.
- `send` est le seul endroit où l'état change.
- L'historique garde (langue, mot), jamais un identifiant du lexique.
- L'interface parle anglais, français et vietnamien. Tout le texte vient de `Copy.swift` et passe par l'état des écrans : une vue n'écrit aucun mot. La langue suit celle que le système donne à l'app.
- Pas de liste de favoris : l'app garde l'historique, et le reel (« Lướt ôn ») le fait réviser.
- Le reel ne finit pas. Un cœur fait revenir un mot deux fois par tour. Entre les mots viennent des
  surprises : une question, un mot nouveau, le compte de la série. Leur tirage passe par `chance`,
  que les fixtures remplacent : les tests ne doivent rien au hasard.
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
