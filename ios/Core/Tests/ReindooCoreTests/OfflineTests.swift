import Foundation
import Testing
@testable import ReindooCore

/// Un serveur de fixture : il note ce qu'il reçoit, et tombe sur commande.
actor FakeServer: SyncClient {
    var received: [Change] = []
    var failures: [SyncError?] = []
    var rejectWords: Set<String> = []

    func failNext(_ errors: SyncError?...) { failures = errors }
    func reject(_ word: String) { rejectWords.insert(word) }

    nonisolated func push(_ change: Change) async throws(SyncError) {
        try await accept(change)
    }

    private func accept(_ change: Change) throws(SyncError) {
        if !failures.isEmpty, let failure = failures.removeFirst() { throw failure }
        if rejectWords.contains(change.key.word) { throw .rejected("mot refusé") }
        // Idempotent : un identifiant déjà vu est déjà fait.
        if !received.contains(where: { $0.id == change.id }) { received.append(change) }
    }
}

@MainActor
@Suite struct Outbox {
    @Test func everyLocalWriteQueuesOneChange() throws {
        let app = try Harness()
        try app.search("aller")
        try app.do("back")
        try app.search("venir")

        let changes = try app.app.user.pendingChanges()
        #expect(changes.map(\.kind) == [.historyAdd, .historyAdd])
        #expect(changes.map(\.key.word) == ["aller", "venir"])
        #expect(try app.appState("pendingChanges") == 2)
    }

    @Test func theLastWriteOnAWordReplacesTheEarlierOne() throws {
        let app = try Harness()
        try app.search("aller")
        try app.do("back")
        try app.search("aller")
        #expect(try app.app.user.pendingChanges().map(\.kind) == [.historyAdd])

        // Cherché puis oublié : seul l'oubli part.
        try app.do("selectTab", #"{"name":"history"}"#)
        try app.do("remove", #"{"word":"aller","language":"french"}"#)
        #expect(try app.app.user.pendingChanges().map(\.kind) == [.historyDelete])
        #expect(try app.appState("pendingChanges") == 1)
    }

    @Test func drainingSendsOldestFirstAndEmptiesTheQueue() async throws {
        let app = try Harness(.returning)
        let server = FakeServer()
        let syncer = Syncer(store: app.app.user, client: server)

        #expect(try await syncer.drain() == .sent(4))
        #expect(try app.app.user.pendingCount() == 0)
        #expect(await server.received.map(\.key.word) == ["élève", "venir", "go", "aller"])
        #expect(try await syncer.drain() == .upToDate)
    }

    @Test func anOutageStopsTheDrainAndNothingIsLostOrDoubled() async throws {
        let app = try Harness(.returning)
        let server = FakeServer()
        let syncer = Syncer(store: app.app.user, client: server)

        await server.failNext(nil, nil, .unavailable)
        #expect(try await syncer.drain() == .interrupted(sent: 2))
        #expect(try app.app.user.pendingCount() == 2)

        // L'app continue de marcher pendant la coupure.
        try app.search("allumer")
        #expect(try app.state("status") == "found")

        #expect(try await syncer.drain() == .sent(3))
        let words = await server.received.map(\.key.word)
        #expect(words == ["élève", "venir", "go", "aller", "allumer"])
        #expect(Set(await server.received.map(\.id)).count == 5)
    }

    @Test func aRejectedChangeIsParkedAndDoesNotBlockTheRest() async throws {
        let app = try Harness(.returning)
        let server = FakeServer()
        await server.reject("go")
        let syncer = Syncer(store: app.app.user, client: server)

        #expect(try await syncer.drain() == .sent(3))
        #expect(try app.app.user.pendingCount() == 0)
        #expect(try app.app.user.parkedCount() == 1)
        #expect(await server.received.map(\.key.word) == ["élève", "venir", "aller"])
    }
}

@MainActor
@Suite struct Storage {
    @Test func userDataSurvivesReopeningAndALexiconRebuild() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("reindoo-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let userPath = directory.appendingPathComponent("user.sqlite").path
        let lexiconPath = directory.appendingPathComponent("lexicon.sqlite").path

        _ = try LexiconBuilder.build(ndjson: [Fixture.sampleNDJSON], to: lexiconPath)
        do {
            let session = Session(app: AppModel(lexicon: try Lexicon(path: lexiconPath), user: try UserStore(path: userPath), copy: Harness.copy))
            try session.perform("open", input: #"{"word":"aller"}"#)
        }

        // Le lexique est remplacé en entier, sans « aller » cette fois.
        let smaller = Fixture.sampleNDJSON.split(separator: "\n").filter { !$0.contains(#""word":"aller""#) }.joined(separator: "\n")
        let report = try LexiconBuilder.build(ndjson: [smaller], to: lexiconPath)
        #expect(report.entries == 11)

        let session = Session(app: AppModel(lexicon: try Lexicon(path: lexiconPath), user: try UserStore(path: userPath), copy: Harness.copy))
        try session.perform("selectTab", input: #"{"name":"history"}"#)
        let items = (try session.ls()["state"] as? [String: Any])?["items"] as? [[String: Any]]
        #expect(items?.first?["word"] as? String == "aller")
        #expect(items?.first?["gloss"] as? String == Harness.copy.missingEntry, "l'historique survit ; le mot disparu est dit disparu")

        // La révision passe un mot qui n'a plus de sens à cacher.
        try session.perform("selectTab", input: #"{"name":"review"}"#)
        let cards = (try session.ls()["state"] as? [String: Any])?["cards"] as? [Any]
        #expect(cards?.isEmpty == true)
    }

    @Test func aLexiconOfTheWrongSchemaIsRefusedClearly() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("reindoo-bad-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        try Data("pas une base".utf8).write(to: URL(fileURLWithPath: path))
        #expect(throws: DatabaseError.self) { _ = try Lexicon(path: path) }
        #expect(throws: DatabaseError.self) { _ = try Lexicon(path: path + ".absent") }
    }

    @Test func theBuilderCountsWhatItSkips() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("reindoo-build-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let source = Fixture.sampleNDJSON + "\n" + #"{"_collection":"dictionary","word":"hola","sourceLanguage":"spanish"}"# + "\npas du json\n"
        let report = try LexiconBuilder.build(ndjson: [source], to: path)
        #expect(report == LexiconBuilder.Report(entries: 12, forms: 5, skipped: 2))
        #expect(try Lexicon(path: path).count(.french) == 9)
    }
}

@Suite struct Primitives {
    @Test func aPackedEntryUnpacksToTheSameEntry() throws {
        let full = Entry(
            word: "pomme de terre", language: .french, translated: "Khoai tây",
            explains: [
                Sense(explain: "(Danh từ) Khoai tây", synonyms: ["patate"], antonyms: [],
                      exampleSentences: [Example(sourceSentence: "Une pomme de terre.", targetTranslation: "Một củ khoai tây.")]),
                Sense(explain: "Củ"),
            ],
            ipa: ["/pɔm də tɛʁ/"], audio: "https://example.org/a.mp3",
            wiki: "https://vi.wiktionary.org/wiki/pomme_de_terre#Ti%E1%BA%BFng_Ph%C3%A1p", derived: ["pomme"]
        )
        var bare = Entry(word: "élève", language: .french, translated: "Học sinh")
        var elsewhere = bare
        elsewhere.wiki = "https://example.org/eleve"
        bare.wiki = nil

        for entry in [full, bare, elsewhere] {
            let data = try JSONEncoder().encode(Packed(entry))
            let back = try JSONDecoder().decode(Packed.self, from: data).entry(word: entry.word, language: entry.language)
            #expect(back == entry)
        }
        // L'adresse qui se déduit du mot ne prend aucune place.
        #expect(Packed(full).w == nil)
        #expect(Packed.wiki(for: "élève", in: .english) == "https://vi.wiktionary.org/wiki/%C3%A9l%C3%A8ve#Ti%E1%BA%BFng_Anh")
    }

    @Test func editDistanceIsBounded() {
        #expect(Text.editDistance("aller", "aller", max: 3) == 0)
        #expect(Text.editDistance("alller", "aller", max: 3) == 1)
        #expect(Text.editDistance("chat", "chien", max: 3) == 3)
        #expect(Text.editDistance("a", "abcdefgh", max: 3) == 4)
        #expect(Text.editDistance("", "ab", max: 3) == 2)
    }

    @Test func foldingDropsCaseAndAccents() {
        #expect(Text.fold("Élève") == "eleve")
        #expect(Text.fold("ÇA") == "ca")
    }
}
