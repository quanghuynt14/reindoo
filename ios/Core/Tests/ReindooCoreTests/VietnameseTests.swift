import Foundation
import Testing
@testable import ReindooCore

/// Việt–Pháp : un mot vietnamien, expliqué en français. Les lignes du
/// lexique de test sont celles du vrai, abrégées.
@MainActor
@Suite struct VietnameseLookups {
    private func vietnamese() throws -> Harness {
        let app = try Harness()
        try app.do("setLanguage", #"{"name":"vietnamese"}"#)
        return app
    }

    @Test func theSearchOffersVietnameseAsAThirdLanguage() throws {
        let app = try vietnamese()
        #expect(try app.state("languages.2.label") == Harness.copy.languageShort(.vietnamese))
        #expect(try app.state("languages.2.isSelected") == true)
        #expect(try app.state("prompt") == Harness.copy.searchPrompt(.vietnamese))
    }

    @Test func aWordTypedWithoutAccentsOpensTheMostFrequentReading() throws {
        let app = try vietnamese()
        // « an » existe tel quel, mais « ăn » est bien plus courant.
        try app.search("an")
        #expect(try app.state("word") == "ăn")
        #expect(try app.state("translated") == "Manger / Bénéficier (d’un avantage) / Valoir")
        #expect(try app.state("alsoFrom") == ["an", "án"])
        #expect(try app.state("matchedNote", as: String.self) == nil, "sans accents, ce n'est pas « une forme de »")

        // Taper l'accent, c'est choisir.
        try app.do("back")
        try app.search("án")
        #expect(try app.state("word") == "án")
    }

    @Test func reindooSensesComeFirstAndWiktionaryFollowsUnderItsOwnTitle() throws {
        let app = try vietnamese()
        try app.search("đẹp")
        #expect(try app.state("translated") == "beau, joli / bon")
        #expect(try app.state("senses.0.heading") == Harness.copy.ownSenses)
        #expect(try app.state("senses.0.number") == 1)
        #expect(try app.state("senses.0.note") == "Pour un homme, on dit plutôt « đẹp trai ».")
        #expect(try app.state("senses.0.examples.0.targetTranslation") == "Elle est très belle.")
        #expect(try app.state("senses.1.heading", as: String.self) == nil)
        #expect(try app.state("senses.1.explain") == "(Adjectif) [familier] bon, réussi")
        // Le Wiktionnaire suit, tel quel, et ses numéros repartent de 1.
        #expect(try app.state("senses.2.heading") == Harness.copy.wiktionarySenses(in: .french))
        #expect(try app.state("senses.2.number") == 1)
        #expect(try app.state("senses.2.explain") == "(Adjectif) Beau.")
        #expect(try app.state("senses.2.note", as: String.self) == nil)
    }

    @Test func anEntryInOneLanguageHasNoTitles() throws {
        let app = try vietnamese()
        try app.search("ăn")
        #expect(try app.state("senses.0.heading", as: String.self) == nil)
        #expect(try app.state("senses.2.number") == 3)
        #expect(try app.state("alsoTranslated", as: String.self) == nil)
        #expect(try app.state("translatedTag", as: String.self) == nil)
    }

    @Test func aReindooSenseCarriesItsEnglishAndTheTopShowsBothLanguages() throws {
        let app = try vietnamese()
        try app.search("đẹp")
        #expect(try app.state("senses.0.english") == "beautiful, pretty")
        #expect(try app.state("senses.0.englishTag") == "EN")
        #expect(try app.state("senses.1.english", as: String.self) == nil)
        #expect(try app.state("translatedTag") == "FR")
        // L'anglais des sens reindoo passe avant celui du Wiktionnaire.
        #expect(try app.state("alsoTranslated") == "beautiful, pretty")
        #expect(try app.state("alsoTranslatedTag") == "EN")
        // Les deux sens anglais du Wiktionnaire ferment la marche, sous leur titre.
        #expect(try app.state("senses.3.heading") == Harness.copy.wiktionarySenses(in: .english))
        #expect(try app.state("senses.3.language") == "english")
    }

    @Test func anEnglishOnlyWordHasOneLineAndNoTags() throws {
        let app = try vietnamese()
        try app.search("nợ")
        #expect(try app.state("senses.0.explain") == "(Nom) debt")
        #expect(try app.state("senses.0.heading", as: String.self) == nil)
        #expect(try app.state("alsoTranslated", as: String.self) == nil)
    }

    @Test func dIsFoldedLikeAnAccent() throws {
        let app = try vietnamese()
        try app.search("dep")
        #expect(try app.state("word") == "đẹp")
        #expect(Text.fold("Đẹp") == "dep")
        #expect(Text.isBare("dep") && !Text.isBare("đep"))
    }

    @Test func theOtherToneSpellingLeadsToTheSameWord() throws {
        let app = try vietnamese()
        try app.search("hoà")
        #expect(try app.state("word") == "hòa")
        #expect(try app.state("matchedNote", as: String.self) == nil)
    }

    @Test func aTypedAccentIsNeverDroppedToFindSomethingElse() throws {
        let app = try vietnamese()
        // « ẳn » n'existe pas. Le repli sans accents mènerait à « ăn » — un
        // autre mot. On propose, on ne remplace pas.
        try app.search("ẳn")
        #expect(try app.state("status") == "notFound")
        let suggestions: [String] = try #require(try app.state("suggestions"))
        #expect(suggestions.contains("ăn"))
    }

    @Test func frenchComesFirstAndEnglishIsMarked() throws {
        let app = try vietnamese()
        try app.search("tham nhung")
        #expect(try app.state("word") == "tham nhũng")
        #expect(try app.state("translated") == "Tracassier et cupide")
        #expect(try app.state("senses.0.explain") == "(Verbe) Tracassier et cupide.")
        // La marque [EN] devient une langue, et un titre au-dessus de la partie.
        #expect(try app.state("senses.1.explain") == "(Verbe) to be corrupt, to engage in corrupt practices")
        #expect(try app.state("senses.1.language") == "english")
        #expect(try app.state("senses.1.heading") == Harness.copy.wiktionarySenses(in: .english))
        #expect(try app.state("senses.1.number") == 1)
        #expect(try app.state("alsoTranslated") == "to be corrupt, to engage in corrupt practices / corruption")
        #expect(try app.state("senses.2.examples.0.targetTranslation") == "to fight corruption")
        #expect(try app.state("wiki") == "https://fr.wiktionary.org/wiki/tham_nh%C5%A9ng#Vietnamien")
    }

    @Test func aWordOnlyEnglishWiktionaryKnowsKeepsItsAddress() throws {
        let app = try vietnamese()
        try app.search("nợ")
        #expect(try app.state("translated") == "debt / to owe")
        #expect(try app.state("wiki") == "https://en.wiktionary.org/wiki/n%E1%BB%A3#Vietnamese")
        #expect(Packed.wiki(for: "ăn", in: .vietnamese) == "https://fr.wiktionary.org/wiki/%C4%83n#Vietnamien")
    }

    @Test func aVietnameseWordTypedOnTheFrenchSideIsFoundElsewhere() throws {
        let app = try Harness()
        try app.search("tham nhũng")
        #expect(try app.state("status") == "notFound")
        #expect(try app.state("elsewhere.0.language") == "vietnamese")
        #expect(try app.state("elsewhere.0.word") == "tham nhũng")
    }

    @Test func frenchAndEnglishSearchesAreUnchanged() throws {
        // Le repli sans accents reste celui d'avant pour les autres langues :
        // « eleve » mène à « élève », sans détour par l'index des formes.
        let app = try Harness()
        try app.search("eleve")
        #expect(try app.state("word") == "élève")
    }
}
