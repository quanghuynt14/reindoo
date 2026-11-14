# Third-party notices

The MIT License in this repository covers Reindoo's own code. It does not cover the material below.

## Dictionary data

The dictionary entries come from the [Vietnamese Wiktionary](https://vi.wiktionary.org), compiled by [dictionnaire](https://github.com/quanghuynt14/dictionnaire). Wiktionary text is available under the [Creative Commons Attribution-ShareAlike 4.0 License](https://creativecommons.org/licenses/by-sa/4.0/).

No dictionary data is stored in this repository beyond a few sample entries used by tests. The iOS build downloads the compiled data and bundles it in the app, and the app links each entry back to its Wiktionary page.

## SQLite

`ios/Core/Sources/CSQLite` contains the [SQLite](https://sqlite.org) amalgamation, which its authors have placed in the public domain.

## Reel scenes

The animated scenes behind the iOS reel (`ios/Core/Sources/ReindooCore/Scenery`) are ported from the `theme-examples` plugin for Claude Code, version 0.4.3, by Anthropic, under the [Apache License 2.0](ios/Core/Licenses/theme-examples-Apache-2.0.txt).

Changes: the TypeScript scene generators were rewritten in Swift and emit a typed scene model instead of SVG text. Each scene keeps its original layout and gains a portrait layout for a phone. Aurora Snow combines two of them.

## Other dependencies

The web app and the API use the npm packages listed in `pnpm-lock.yaml`, each under its own license.
