# Third-party notices

The MIT License in this repository covers Reindoo's own code. It does not cover the material below.

## Dictionary data

The dictionary entries come from the [Vietnamese Wiktionary](https://vi.wiktionary.org), compiled by [dictionnaire](https://github.com/quanghuynt14/dictionnaire). Wiktionary text is available under the [Creative Commons Attribution-ShareAlike 4.0 License](https://creativecommons.org/licenses/by-sa/4.0/).

No dictionary data is stored in this repository beyond a few sample entries used by tests. The iOS build downloads the compiled data and bundles it in the app, and the app links each entry back to its Wiktionary page.

## SQLite

`ios/Core/Sources/CSQLite` contains the [SQLite](https://sqlite.org) amalgamation, which its authors have placed in the public domain.

## Other dependencies

The web app and the API use the npm packages listed in `pnpm-lock.yaml`, each under its own license.
