import Foundation
import Testing
@testable import ReindooCore

@Suite struct Scheduling {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let day = 86_400.0

    @Test func aFirstAnswerSetsTheFirstInterval() {
        let knew = FSRS.first(.knew, at: start)
        #expect(abs(knew.stability - 3.173) < 1e-9)
        #expect(knew.due == start.addingTimeInterval(3 * day))
        #expect(knew.lapses == 0)

        let forgot = FSRS.first(.forgot, at: start)
        #expect(forgot.due == start.addingTimeInterval(day), "jamais moins d'un jour")
        #expect(forgot.lapses == 1)
        #expect(forgot.difficulty > knew.difficulty)
    }

    @Test func theChanceOfRememberingIsNinetyPercentAfterOneStability() {
        let memory = FSRS.first(.knew, at: start)
        let then = start.addingTimeInterval(memory.stability * day)
        #expect(abs(memory.retrievability(at: then) - 0.9) < 1e-9)
        #expect(memory.retrievability(at: start) == 1)
        #expect(memory.retrievability(at: then.addingTimeInterval(30 * day)) < 0.9)
    }

    @Test func rememberingOnTimeStretchesTheIntervalAndForgettingShrinksIt() {
        let first = FSRS.first(.knew, at: start)
        let knew = FSRS.next(first, .knew, at: first.due)
        #expect(knew.stability > first.stability * 2)
        #expect(knew.due.timeIntervalSince(first.due) > first.due.timeIntervalSince(start))

        let forgot = FSRS.next(knew, .forgot, at: knew.due)
        #expect(forgot.stability < knew.stability)
        #expect(forgot.difficulty > knew.difficulty)
        #expect(forgot.lapses == 1 && forgot.reviews == 3)
    }

    @Test func twiceTheSameDayCountsButLittle() {
        let first = FSRS.first(.knew, at: start)
        let again = FSRS.next(first, .knew, at: start.addingTimeInterval(60))
        #expect(again.stability > first.stability)
        #expect(again.stability < first.stability * 1.5)
    }

    @Test func difficultyStaysBetweenOneAndTen() {
        var easy = FSRS.first(.knew, at: start), hard = FSRS.first(.forgot, at: start)
        for _ in 0..<50 {
            easy = FSRS.next(easy, .knew, at: easy.due)
            hard = FSRS.next(hard, .forgot, at: hard.due)
        }
        #expect((1...10).contains(easy.difficulty))
        #expect((1...10).contains(hard.difficulty))
        #expect(easy.due.timeIntervalSince(easy.reviewedAt) <= FSRS.maximumDays * day)
    }
}

@MainActor
@Suite struct Remembering {
    private func cards(_ app: Harness) throws -> [[String: Any]] {
        try #require(try app.state("cards"))
    }

    private func words(_ app: Harness) throws -> [String] {
        try cards(app).compactMap { $0["word"] as? String }
    }

    private func scroll(_ app: Harness, to index: Int) throws {
        let from: Int = try #require(try app.state("position"))
        guard index > from else { return }
        for step in (from + 1)...index { try app.do("setPosition", #"{"index":\#(step)}"#) }
    }

    @Test func anAnswerComesOnlyAfterTheMeaningAndOnlyOnce() throws {
        let app = try Harness(.returning)
        let queued = try app.app.user.pendingCount()
        try app.do("selectTab", #"{"name":"review"}"#)
        #expect(try app.state("knewLabel") == Harness.copy.knewIt)
        #expect(try app.state("forgotLabel") == Harness.copy.notYet)

        try app.do("answer", #"{"name":"knew"}"#)
        #expect(try app.app.user.recalls().isEmpty, "le sens caché, on ne répond pas")

        try app.do("reveal")
        try app.do("answer", #"{"name":"knew"}"#)
        try app.do("answer", #"{"name":"forgot"}"#)
        #expect(try app.state("cards.0.recall") == "knew")
        #expect(try app.app.user.recalls().map(\.answer) == [.knew])
        #expect(try app.app.user.memory(WordKey(.french, "aller")) != nil)
        #expect(try app.app.user.pendingCount() == queued, "la mémoire reste sur l'appareil")

        #expect(throws: IntrospectionError.badInput(action: "answer", expected: "{name: knew|forgot, id?}")) {
            try app.do("answer", #"{"name":"maybe"}"#)
        }
    }

    @Test func aKnownWordWaitsAtTheBackUntilItIsDue() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        #expect(try words(app) == ["aller", "élève", "go", "venir"])

        try app.do("reveal")
        try app.do("answer", #"{"name":"knew"}"#)
        try app.do("restart")
        #expect(try words(app) == ["élève", "go", "venir", "aller"], "les mots sans réponse d'abord")

        // Trois jours plus tard, le calendrier l'attend : il passe en tête.
        app.clock.now += 4 * 86_400
        try app.do("restart")
        #expect(try words(app) == ["aller", "élève", "go", "venir"])
    }

    @Test func theWordClosestToBeingForgottenComesFirst() throws {
        let app = try Harness(.returning)
        let user = app.app.user
        // « venir » su il y a longtemps, « go » oublié : les deux sont dus.
        try user.recall(WordKey(.french, "venir"), .knew)
        try user.recall(WordKey(.english, "go"), .forgot)
        app.clock.now += 30 * 86_400
        try app.do("selectTab", #"{"name":"review"}"#)
        // Le paquet a été tiré au lancement, avant ces réponses.
        try app.do("restart")
        #expect(Array(try words(app).prefix(2)) == ["go", "venir"])
        #expect(Array(try words(app).suffix(2)) == ["aller", "élève"])
    }

    @Test func aForgottenWordComesBackHiddenAFewCardsLater() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        try scroll(app, to: 7)
        let at: Int = try #require(try app.state("position"))
        let card = try cards(app)[at]
        #expect(card["kind"] as? String == "word")
        let word = try #require(card["word"] as? String)
        let before = try cards(app).compactMap { $0["id"] as? String }

        try app.do("reveal")
        try app.do("answer", #"{"name":"forgot"}"#)
        let after = try cards(app)
        #expect(after.count == before.count + 1)
        let inserted = try #require(after.indices.first { $0 >= before.count || after[$0]["id"] as? String != before[$0] })
        #expect(inserted >= at + 5)
        #expect(after[inserted]["word"] as? String == word)
        #expect(after[inserted]["isRevealed"] as? Bool == false)
        #expect(after[inserted - 1]["word"] as? String != word)
        if inserted + 1 < after.count { #expect(after[inserted + 1]["word"] as? String != word) }
    }

    @Test func aQuizAnswerCountsAsARecall() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        try scroll(app, to: 12)
        let quiz = try #require(try cards(app).firstIndex { $0["kind"] as? String == "quiz" })
        try app.do("setPosition", #"{"index":\#(quiz)}"#)
        let choices = try #require(try cards(app)[quiz]["choices"] as? [[String: Any]])
        let wrong = try #require(choices.firstIndex { $0["isCorrect"] as? Bool == false })
        try app.do("choose", #"{"index":\#(wrong)}"#)

        let word = try #require(try cards(app)[quiz]["word"] as? String)
        #expect(try app.app.user.recalls().map(\.answer) == [.forgot])
        #expect(try app.app.user.recalls().first?.key.word == word)
        // Une question n'attend pas de seconde réponse.
        try app.do("answer", #"{"name":"knew"}"#)
        #expect(try app.app.user.recalls().count == 1)
    }

    @Test func answersSurviveReopening() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("reindoo-memory-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let key = WordKey(.french, "aller")
        let first = try UserStore(path: path, now: { Date(timeIntervalSince1970: 1_800_000_000) })
        let memory = try first.recall(key, .knew)
        let again = try UserStore(path: path)
        #expect(try again.memory(key) == memory)
        #expect(try again.recalls().count == 1)
    }
}
