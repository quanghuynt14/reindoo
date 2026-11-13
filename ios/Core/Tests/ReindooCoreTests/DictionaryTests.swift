import Foundation
import Testing
@testable import ReindooCore

@MainActor
@Suite struct DictionaryJourneys {
    @Test func typingOffersCompletionsAndSubmitOpensWhatWasTyped() throws {
        let app = try Harness()
        #expect(try app.screen == "search")
        #expect(try app.state("emptyMessage") == Harness.copy.searchEmpty)

        try app.do("setQuery", #"{"text":"all"}"#)
        #expect(try app.state("completions") == ["aller", "allumer", "allée", "allier"])

        // Valider ouvre ce qui est tapé, pas la première complétion.
        try app.do("submit")
        #expect(try app.screen == "entry")
        #expect(try app.state("status") == "notFound")

        // Toucher une complétion ouvre ce mot-là.
        try app.do("back")
        #expect(try app.state("query") == "all", "la saisie survit à l'aller-retour")
        try app.do("open", #"{"word":"allumer"}"#)
        #expect(try app.state("word") == "allumer")
    }

    @Test func foundEntryShowsEverythingTheLexiconKnows() throws {
        let app = try Harness()
        try app.search("aller")

        #expect(try app.screen == "entry")
        #expect(try app.state("status") == "found")
        #expect(try app.state("word") == "aller")
        #expect(try app.state("translated") == "đi")
        #expect(try app.state("ipa") == "/a.le/")
        #expect(try app.state("senses.0.explain") == "Đi, di chuyển từ nơi này đến nơi khác.")
        #expect(try app.state("senses.0.examples.0.sourceSentence") == "Je vais à l'école.")
        #expect(try app.state("senses.1.number") == 2)
        #expect(try app.state("derived") == ["allée", "s'en aller"])
        #expect(try app.state("senses.0.synonymsTitle") == Harness.copy.synonyms)
    }

    @Test func inflectedFormResolvesToTheMostFrequentLemma() throws {
        let app = try Harness()
        try app.search("allions")

        #expect(try app.state("word") == "aller")
        #expect(try app.state("matchedNote") == Harness.copy.matchedForm("allions", "aller"))
        #expect(try app.state("alsoFrom") == ["allier"])

        // Suivre l'autre vedette empile une entrée ; revenir la dépile.
        try app.do("open", #"{"word":"allier"}"#)
        #expect(try app.state("word") == "allier")
        #expect(try app.appState("depth") == 2)
        try app.do("back")
        #expect(try app.state("word") == "aller")
    }

    @Test func aHeadwordThatIsAlsoAFormNamesItsLemma() throws {
        let app = try Harness()
        try app.do("setLanguage", #"{"name":"english"}"#)
        try app.search("went")

        // « went » a sa propre entrée, qui n'est qu'un renvoi : on nomme « go ».
        #expect(try app.state("word") == "went")
        #expect(try app.state("matchedNote", as: String.self) == nil)
        #expect(try app.state("alsoFrom") == ["go"])
    }

    @Test func aPhoneKeyboardIsForgiven() throws {
        let app = try Harness()

        try app.search("Aller")  // majuscule automatique
        #expect(try app.state("word") == "aller")
        try app.do("back")

        try app.search("eleve")  // accents oubliés
        #expect(try app.state("word") == "élève")
        try app.do("back")

        try app.search("  venir \n")  // espaces autour
        #expect(try app.state("word") == "venir")
        try app.do("back")

        // La casse exacte gagne quand elle existe : Paris n'est pas pari.
        try app.search("Paris")
        #expect(try app.state("word") == "Paris")
        try app.do("back")
        try app.search("pari")
        #expect(try app.state("word") == "pari")
    }

    @Test func completionsIgnoreAccentsAndPutTheExactWordFirst() throws {
        let app = try Harness()
        try app.do("setQuery", #"{"text":"ele"}"#)
        #expect(try app.state("completions") == ["élève", "élever"])
        try app.do("setQuery", #"{"text":"allier"}"#)
        #expect(try app.state("completions") == ["allier"])
        try app.do("clear")
        #expect(try app.state("completions") == [String]())
    }

    @Test func languagesDoNotLeakIntoEachOther() throws {
        let app = try Harness()
        try app.search("go")
        #expect(try app.state("status") == "notFound")
        try app.do("back")

        try app.do("setLanguage", #"{"name":"english"}"#)
        #expect(try app.state("prompt") == Harness.copy.searchPrompt(.english))
        try app.do("submit")
        #expect(try app.state("word") == "go")
        #expect(try app.state("ipa") == "/ɡəʊ/ · /ɡoʊ/")
    }
}

@MainActor
@Suite struct NotFound {
    @Test func aMissingWordIsSaidMissingWithSuggestions() throws {
        let app = try Harness()
        try app.search("alller")

        #expect(try app.screen == "entry")
        #expect(try app.state("status") == "notFound")
        #expect(try app.state("title") == Harness.copy.notFound("alller"))
        #expect(try app.state("hint") == Harness.copy.notFoundHint)
        let suggestions: [String] = try #require(try app.state("suggestions"))
        #expect(suggestions.first == "aller")
        #expect(suggestions.contains("allier"))

        try app.do("open", #"{"word":"aller"}"#)
        #expect(try app.state("word") == "aller")
    }

    @Test func aMissingWordLeavesNoTrace() throws {
        let app = try Harness()
        try app.search("zzzz")
        #expect(try app.state("hint") == Harness.copy.notFoundNoHint)
        #expect(try app.state("suggestions") == [String]())
        #expect(try app.state("elsewhere") == [Any]() as NSArray)

        // Pas d'historique pour un mot qui n'existe pas.
        try app.do("back")
        #expect(try app.state("recents") == [String]())
        #expect(try app.appState("pendingChanges") == 0)
    }

    @Test func aWordFromTheOtherDictionaryIsOfferedNotInvented() throws {
        let app = try Harness()
        try app.search("goes")

        #expect(try app.state("status") == "notFound")
        #expect(try app.state("elsewhere.0.language") == "english")
        #expect(try app.state("elsewhere.0.title") == Harness.copy.foundElsewhere(.english))
        #expect(try app.state("elsewhere.0.word") == "go")

        try app.do("openElsewhere", #"{"name":"english"}"#)
        #expect(try app.state("status") == "found")
        #expect(try app.state("language") == "english")
        #expect(try app.state("word") == "go")
        #expect(try app.state("matchedNote") == Harness.copy.matchedForm("goes", "go"))

        // Une langue qui ne l'a pas ne s'ouvre pas.
        try app.do("back")
        try app.do("openElsewhere", #"{"name":"french"}"#)
        #expect(try app.state("status") == "notFound")
    }

    @Test func anEmptyQueryGoesNowhere() throws {
        let app = try Harness()
        try app.do("setQuery", #"{"text":"   "}"#)
        try app.do("submit")
        #expect(try app.screen == "search")
        #expect(try app.appState("depth") == 0)
    }
}

@MainActor
@Suite struct History {
    @Test func searchesBecomeRecentsNewestFirstWithoutDuplicates() throws {
        let app = try Harness()
        for word in ["aller", "venir", "aller"] {
            try app.search(word)
            try app.do("back")
        }
        #expect(try app.state("recents") == ["aller", "venir"])
        #expect(try app.state("emptyMessage", as: String.self) == nil)

        // Les récents suivent la langue choisie.
        try app.do("setLanguage", #"{"name":"english"}"#)
        #expect(try app.state("recents") == [String]())
    }

    @Test func historyListsEveryWordAndForgetsOnRequest() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"history"}"#)
        #expect(try app.screen == "history")
        #expect(try app.state("emptyMessage") == Harness.copy.historyEmpty)

        try app.do("selectTab", #"{"name":"search"}"#)
        try app.search("élève")
        try app.do("selectTab", #"{"name":"history"}"#)
        #expect(try app.state("items.0.word") == "élève")
        #expect(try app.state("items.0.gloss") == "học sinh")
        #expect(try app.state("items.0.languageLabel") == "Pháp")
        #expect(try app.state("emptyMessage", as: String.self) == nil)

        try app.do("remove", #"{"word":"élève","language":"french"}"#)
        #expect(try app.state("emptyMessage") == Harness.copy.historyEmpty)
    }

    @Test func aReturningUserFindsTheirWords() throws {
        let app = try Harness(.returning)
        #expect(try app.state("recents") == ["aller", "venir", "élève"])

        try app.do("selectTab", #"{"name":"history"}"#)
        #expect(try app.state("items.0.word") == "aller")
        #expect(try app.state("items.1.word") == "go")
        #expect(try app.state("items.2.word") == "venir")
        #expect(try app.state("items.3.word") == "élève")

        // Ouvrir depuis l'historique empile sur cet onglet, dans la bonne
        // langue ; et le mot revu remonte en tête.
        try app.do("open", #"{"word":"go","language":"english"}"#)
        #expect(try app.screen == "entry")
        #expect(try app.state("translated") == "đi")
        try app.do("back")
        #expect(try app.state("items.0.word") == "go")
    }

    /// Le geste de retour et le bouton passent tous deux par `popTo` : c'est
    /// la vue qui l'envoie, pas le CLI. Il avait échappé aux tests, et il
    /// plantait.
    @Test func theBackGestureShortensTheStack() throws {
        let app = try Harness(.returning)
        try app.search("allions")
        try app.do("open", #"{"word":"allier"}"#)
        try app.do("open", #"{"word":"aller"}"#)
        #expect(try app.appState("depth") == 3)

        app.app.send(.popTo(2))
        #expect(try app.state("word") == "allier")
        app.app.send(.popTo(0))
        #expect(try app.screen == "search")

        // Une profondeur qui ne raccourcit rien est ignorée.
        app.app.send(.popTo(0))
        app.app.send(.popTo(5))
        app.app.send(.popTo(-1))
        #expect(try app.appState("depth") == 0)
    }

    @Test func eachTabKeepsItsOwnStackAndRetappingPopsToRoot() throws {
        let app = try Harness(.returning)
        try app.search("aller")
        try app.do("open", #"{"word":"allée"}"#)
        #expect(try app.appState("depth") == 2)

        try app.do("selectTab", #"{"name":"history"}"#)
        #expect(try app.screen == "history")
        try app.do("selectTab", #"{"name":"search"}"#)
        #expect(try app.state("word") == "allée", "la pile de l'onglet survit au changement d'onglet")

        try app.do("selectTab", #"{"name":"search"}"#)
        #expect(try app.screen == "search")
    }
}

@MainActor
@Suite struct Review {
    private func cards(_ app: Harness) throws -> [[String: Any]] {
        try #require(try app.state("cards"))
    }

    private func words(_ app: Harness) throws -> [String] {
        try cards(app).compactMap { $0["word"] as? String }
    }

    private func ids(_ app: Harness) throws -> [String] {
        try cards(app).compactMap { $0["id"] as? String }
    }

    /// Fait défiler jusqu'à la carte `index`, une carte à la fois, comme un doigt.
    private func scroll(_ app: Harness, to index: Int) throws {
        let from: Int = try #require(try app.state("position"))
        guard index > from else { return }
        for step in (from + 1)...index { try app.do("setPosition", #"{"index":\#(step)}"#) }
    }

    @Test func nothingLookedUpNothingToReview() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"review"}"#)
        #expect(try app.screen == "review")
        #expect(try app.state("emptyMessage") == Harness.copy.reviewEmpty)
        #expect(try cards(app).isEmpty)

        // Sans carte, il n'y a rien à montrer ni à ouvrir.
        try app.do("reveal")
        try app.do("open")
        #expect(try app.screen == "review")
    }

    @Test func theMeaningIsHiddenUntilAsked() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)

        #expect(try words(app) == ["aller", "élève", "go", "venir"], "le hasard de la fixture")
        #expect(try app.state("cards.0.isRevealed") == false)
        #expect(try app.state("cards.0.gloss") == "đi")
        #expect(try app.state("cards.0.example.sourceSentence") == "Je vais à l'école.")
        #expect(try app.state("revealHint") == Harness.copy.revealHint)

        // Sans identifiant, c'est la carte à l'écran.
        try app.do("reveal")
        #expect(try app.state("cards.0.isRevealed") == true)
        #expect(try app.state("cards.1.isRevealed") == false)

        try app.do("setPosition", #"{"index":2}"#)
        try app.do("reveal")
        #expect(try app.state("cards.2.isRevealed") == true)
        try app.do("reveal", #"{"id":"english/go"}"#)
        #expect(try app.state("cards.2.isRevealed") == false, "retoucher recache")

        try app.do("setPosition", #"{"index":99}"#)
        #expect(try app.state("position") == 2, "une position hors du reel est ignorée")

        // La carte se montre seule après un temps : cela ne recache jamais.
        try app.do("unveil")
        try app.do("unveil")
        #expect(try app.state("cards.2.isRevealed") == true)
    }

    @Test func orderAndLanguageAreTheUsersChoice() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        #expect(try app.state("sort") == "random")
        #expect(try app.state("sortLabel") == Harness.copy.sortRandom)

        try app.do("reveal")
        try app.do("cycleSort")
        #expect(try app.state("sort") == "newest")
        #expect(try words(app) == ["aller", "go", "venir", "élève"])
        #expect(try app.state("cards.0.isRevealed") == false, "un paquet neuf est caché")

        try app.do("cycleSort")
        #expect(try words(app) == ["élève", "venir", "go", "aller"])
        try app.do("cycleSort")
        #expect(try app.state("sort") == "random")

        try app.do("setFilter", #"{"name":"english"}"#)
        #expect(Set(try words(app)) == ["go"])
        #expect(try app.state("filters.2.isSelected") == true)

        try app.do("setSort", #"{"name":"oldest"}"#)
        #expect(try app.state("sorts.2.isSelected") == true)
        #expect(try app.state("sortLabel") == Harness.copy.sortOldest)
        try app.do("setSort", #"{"name":"random"}"#)

        try app.do("setFilter", #"{"name":"all"}"#)
        #expect(try words(app).count == 4)
        #expect(throws: IntrospectionError.badInput(action: "setSort", expected: "{name: random|newest|oldest}")) {
            try app.do("setSort", #"{"name":"alphabetical"}"#)
        }
        #expect(throws: IntrospectionError.badInput(action: "setFilter", expected: "{name: all|french|english}")) {
            try app.do("setFilter", #"{"name":"german"}"#)
        }
    }

    @Test func aLanguageWithNoWordsSaysSo() throws {
        let app = try Harness()
        try app.search("aller")
        try app.do("selectTab", #"{"name":"review"}"#)
        try app.do("setFilter", #"{"name":"english"}"#)
        #expect(try app.state("emptyMessage") == Harness.copy.reviewEmptyFiltered)
    }

    @Test func reviewingAWordDoesNotCountAsLookingItUp() throws {
        let app = try Harness(.returning)
        let before = try app.app.user.history()
        let queued = try app.app.user.pendingCount()

        try app.do("selectTab", #"{"name":"review"}"#)
        try app.do("setPosition", #"{"index":3}"#)
        try app.do("reveal")
        try app.do("open")
        #expect(try app.screen == "entry")
        #expect(try app.state("word") == "venir")
        // Un renvoi suivi depuis là ne compte pas non plus.
        try app.do("open", #"{"word":"aller"}"#)
        #expect(try app.app.user.history() == before)
        #expect(try app.app.user.pendingCount() == queued)

        // Au retour, le paquet n'a pas bougé : même carte, toujours montrée.
        try app.do("back")
        try app.do("back")
        #expect(try app.state("position") == 3)
        #expect(try app.state("cards.3.isRevealed") == true)
    }

    @Test func aNewLookupDealsAFreshDeck() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        try app.do("reveal")

        try app.do("selectTab", #"{"name":"search"}"#)
        try app.search("allumer")
        try app.do("selectTab", #"{"name":"review"}"#)
        #expect(Array(try words(app).prefix(5)) == ["aller", "allumer", "élève", "go", "venir"])
        #expect(try app.state("cards.0.isRevealed") == false)
    }

    @Test func theReelNeverEnds() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        #expect(try cards(app).count == 4, "un tour d'avance suffit au départ")

        // Bien au-delà du nombre de mots : il reste toujours des cartes devant.
        try scroll(app, to: 30)
        #expect(try app.state("position") == 30)
        #expect(try cards(app).count >= 34)
        #expect(Set(try ids(app)).count == (try ids(app)).count, "chaque carte a son identifiant")
        #expect(try app.state("cards.4.id") == "french/aller#2", "le mot revient, sous un autre numéro")

        // Jamais deux fois le même mot de suite.
        let words = try cards(app).filter { $0["kind"] as? String == "word" }.compactMap { $0["word"] as? String }
        #expect(!zip(words, words.dropFirst()).contains { $0 == $1 })

        // Rebattre repart du début.
        try app.do("restart")
        #expect(try app.state("position") == 0)
        #expect(try cards(app).count == 4)
    }

    @Test func aLikedWordComesBackMoreOften() throws {
        let app = try Harness(.returning)
        let queued = try app.app.user.pendingCount()
        try app.do("selectTab", #"{"name":"review"}"#)

        try app.do("like", #"{"id":"french/élève"}"#)
        #expect(try app.state("cards.1.isLiked") == true)
        #expect(try app.app.user.liked() == [WordKey(.french, "élève")])
        #expect(try app.app.user.pendingCount() == queued + 1, "le cœur attend d'être envoyé")

        try scroll(app, to: 12)
        let lap = Array(try words(app)[6...9])
        #expect(lap == ["élève", "go", "élève", "venir"], "deux fois dans le tour, jamais de suite")
        #expect(try app.state("cards.6.isLiked") == true, "toutes ses cartes portent le cœur")

        // Le cœur se retire comme il s'est posé, et le mot reprend son rang.
        try app.do("like", #"{"id":"french/élève#2"}"#)
        #expect(try app.state("cards.1.isLiked") == false)
        #expect(try app.app.user.liked().isEmpty)
        try app.do("restart")
        try scroll(app, to: 4)
        #expect(Array(try words(app).prefix(4)) == ["aller", "élève", "go", "venir"])
    }

    @Test func surprisesBreakTheRoutine() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        try scroll(app, to: 24)
        let kinds = try cards(app).compactMap { $0["kind"] as? String }
        #expect(kinds.prefix(5).allSatisfy { $0 == "word" }, "d'abord cinq mots")

        // Une question sur un mot vu il y a peu. Un seul sens est le bon.
        #expect(kinds[5] == "quiz")
        #expect(try app.state("cards.5.word") == "venir")
        #expect(try app.state("cards.5.badge") == Harness.copy.quizPrompt)
        let choices: [[String: Any]] = try #require(try app.state("cards.5.choices"))
        #expect(choices.count == 4)
        #expect(choices.filter { $0["isCorrect"] as? Bool == true }.compactMap { $0["label"] as? String } == ["đến"])
        #expect(Set(choices.compactMap { $0["label"] as? String }).count == 4)

        // On ne répond qu'une fois.
        try app.do("setPosition", #"{"index":5}"#)
        try app.do("choose", #"{"index":0}"#)
        try app.do("choose", #"{"index":2}"#)
        #expect(try app.state("cards.5.picked") == 0)
        // Répondre ailleurs que sur une question ne fait rien.
        try app.do("setPosition", #"{"index":6}"#)
        try app.do("choose", #"{"index":0}"#)
        #expect(try app.state("cards.6.picked", as: Int.self) == nil)

        // Un mot courant, jamais cherché.
        let discovery = try #require(kinds.firstIndex(of: "discovery"))
        #expect(try app.state("cards.\(discovery).word") == "élever")
        #expect(try app.state("cards.\(discovery).badge") == Harness.copy.newWord)
        #expect(try app.state("cards.\(discovery).isRevealed") == false)

        // Le compte de la série n'a ni sens à montrer ni entrée à ouvrir.
        let streak = try #require(kinds.firstIndex(of: "streak"))
        #expect(try app.state("cards.\(streak).badge") == Harness.copy.streak(20))
        try app.do("setPosition", #"{"index":\#(streak)}"#)
        try app.do("open")
        try app.do("like")
        #expect(try app.screen == "review")
        #expect(try app.app.user.liked().isEmpty)

        // L'écart entre deux surprises varie.
        let at = kinds.indices.filter { kinds[$0] != "word" }
        #expect(Set(zip(at, at.dropFirst()).map { $1 - $0 }).count > 1)
    }

    @Test func aWordKeepsItsColour() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        try scroll(app, to: 4)
        let first: Double = try #require(try app.state("cards.0.hue"))
        #expect(try app.state("cards.4.hue") == first, "aller, au second tour")
        #expect(try app.state("cards.1.hue") != first)
        #expect((0..<1).contains(first))
    }
}

@MainActor
@Suite struct Interface {
    @Test(arguments: UILanguage.allCases)
    func everyScreenSpeaksTheChosenLanguage(ui: UILanguage) throws {
        let copy = Copy(ui)
        let app = try Harness(.returning, ui: ui)

        let tabs: [[String: Any]] = try #require(try app.appState("tabs"))
        #expect(tabs.compactMap { $0["label"] as? String } == [copy.tabSearch, copy.tabReview, copy.tabHistory])
        #expect(try app.state("prompt") == copy.searchPrompt(.french))
        #expect(try app.state("recentsTitle") == copy.recents)

        try app.search("alller")
        #expect(try app.state("title") == copy.notFound("alller"))
        #expect(try app.state("hint") == copy.notFoundHint)
        try app.do("back")

        try app.search("allions")
        #expect(try app.state("matchedNote") == copy.matchedForm("allions", "aller"))
        #expect(try app.state("alsoFromTitle") == copy.alsoFrom)
        // La glose reste celle du lexique.
        #expect(try app.state("translated") == "đi")

        try app.do("selectTab", #"{"name":"review"}"#)
        #expect(try app.state("revealHint") == copy.revealHint)
        #expect(try app.state("filters.0.label") == copy.allLanguages)

        try app.do("selectTab", #"{"name":"history"}"#)
        #expect(try app.state("title") == copy.tabHistory)
        #expect(try app.state("items.0.languageLabel") == copy.languageShort(.french))
    }

    @Test func theThreeLanguagesSayDifferentThings() {
        let labels = UILanguage.allCases.map { Copy($0).tabReview }
        #expect(labels == ["Reels", "Reels", "Lướt ôn"])
        #expect(Copy(.french).searchPrompt(.english) == "Chercher un mot anglais")
        #expect(Copy(.english).pending(1) == "1 change waiting to sync")
        #expect(Copy(.vietnamese).pending(0) == nil)
    }

    @Test func anUnknownLocaleFallsBackToEnglish() {
        #expect(UILanguage(code: "fr-FR") == .french)
        #expect(UILanguage(code: "vi_VN") == .vietnamese)
        #expect(UILanguage(code: "de") == .english)
        #expect(UILanguage(code: nil) == .english)
    }
}

@MainActor
@Suite struct Protocol {
    @Test func unknownActionsAreRefusedAndTheAvailableOnesListed() throws {
        let app = try Harness()
        #expect(throws: IntrospectionError.unknownAction("toggleStar", available: ["appear", "setQuery", "setLanguage", "submit", "open", "clear", "selectTab", "back"])) {
            try app.do("toggleStar")
        }
        #expect(throws: IntrospectionError.badInput(action: "setQuery", expected: "{text}")) {
            try app.do("setQuery", #"{"word":"x"}"#)
        }
        #expect(throws: IntrospectionError.badInput(action: "setLanguage", expected: "{name: french|english}")) {
            try app.do("setLanguage", #"{"name":"german"}"#)
        }
    }

    @Test func lsNamesTheFocusedScreenAndItsPath() throws {
        let app = try Harness()
        try app.search("aller")
        let ls = try app.session.ls()
        #expect(ls["path"] as? [String] == ["app", "entry"])
        #expect((ls["actions"] as? [String])?.contains("back") == true)
    }
}
