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

    private func laps(_ app: Harness) throws -> [Int: [String]] {
        var laps: [Int: [String]] = [:]
        for card in try cards(app) where card["kind"] as? String == "word" {
            laps[card["lap"] as? Int ?? -1, default: []].append(card["word"] as? String ?? "")
        }
        return laps
    }

    @Test func aSwipeAnswersOnceAndMovesOn() throws {
        let app = try Harness(.returning)
        let queued = try app.app.user.pendingCount()
        try app.do("selectTab", #"{"name":"review"}"#)
        #expect(try app.state("knewLabel") == Harness.copy.knewIt)
        #expect(try app.state("forgotLabel") == Harness.copy.again)
        #expect(try app.state("swipeHint") == Harness.copy.swipeHint)

        // Pas besoin d'attendre le sens : on sait souvent dès le mot.
        try app.do("answer", #"{"name":"knew"}"#)
        #expect(try app.state("cards.0.recall") == "knew")
        #expect(try app.state("position") == 1, "le geste passe à la carte suivante")
        #expect(try app.app.user.recalls().map(\.answer) == [.knew])
        #expect(try app.app.user.pendingCount() == queued, "la mémoire reste sur l'appareil")

        // Une carte déjà répondue ne répond plus.
        try app.do("answer", #"{"name":"forgot","id":"french/aller"}"#)
        #expect(try app.app.user.recalls().count == 1)

        #expect(throws: IntrospectionError.badInput(action: "answer", expected: "{name: knew|forgot, id?}")) {
            try app.do("answer", #"{"name":"maybe"}"#)
        }
    }

    @Test func aKnownWordSkipsTwoLapsThenComesBack() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        let first: Int = try #require(try app.state("cards.0.lap"))
        #expect(try words(app) == ["aller", "élève", "go", "venir"])

        try app.do("answer", #"{"name":"knew"}"#)
        try scroll(app, to: 20)
        let laps = try laps(app)
        #expect(laps[first + 1] == ["élève", "go", "venir"])
        #expect(laps[first + 2] == ["élève", "go", "venir"])
        #expect(laps[first + 3]?.contains("aller") == true, "il revient au troisième tour")
    }

    @Test func aKnownWordLeavesALapAlreadyDealt() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        let first: Int = try #require(try app.state("cards.0.lap"))
        try scroll(app, to: 3)
        #expect(try laps(app)[first + 1] != nil, "le tour suivant est déjà tiré")
        let word = try #require(try app.state("cards.3.word", as: String.self))

        try app.do("answer", #"{"name":"knew"}"#)
        try scroll(app, to: 20)
        let laps = try laps(app)
        #expect(laps[first + 1]?.contains(word) == false)
        #expect(laps[first + 2]?.contains(word) == false)
        #expect(laps[first + 3]?.contains(word) == true)
    }

    @Test func aHardWordComesTwiceInEveryLap() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        let first: Int = try #require(try app.state("cards.0.lap"))
        try app.do("answer", #"{"name":"forgot"}"#)
        try scroll(app, to: 20)
        let laps = try laps(app)
        for number in (first + 1)...(first + 2) {
            #expect(laps[number]?.filter { $0 == "aller" }.count == 2, "tour \(number)")
        }
        let words = try cards(app).filter { $0["kind"] as? String == "word" }.compactMap { $0["word"] as? String }
        #expect(!zip(words, words.dropFirst()).contains { $0 == $1 }, "jamais deux fois de suite")

        // Su ensuite, il n'est plus difficile.
        try app.do("answer", #"{"name":"knew","id":"french/aller#2"}"#)
        #expect(try app.app.user.marks()[WordKey(.french, "aller")]?.isHard == false)
    }

    @Test func whenEveryWordIsKnownTheReelStillGoesOn() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        for _ in 0..<4 { try app.do("answer", #"{"name":"knew"}"#) }
        try scroll(app, to: 12)
        #expect(try app.state("position") == 12)
    }

    @Test func theLapCountSurvivesARestart() throws {
        let app = try Harness(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        let first: Int = try #require(try app.state("cards.0.lap"))
        try app.do("restart")
        #expect(try app.state("cards.0.lap") == first + 1)
        #expect(try app.app.user.setting("reel.lap") == String(first + 1))
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
        // Une question ne se balaie pas.
        try app.do("answer", #"{"name":"knew"}"#)
        #expect(try app.app.user.recalls().count == 1)
    }

    @Test func answersSurviveReopening() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("reindoo-memory-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let key = WordKey(.french, "aller")
        let first = try UserStore(path: path, now: { Date(timeIntervalSince1970: 1_800_000_000) })
        let memory = try first.recall(key, .knew)
        try first.mark(WordKey(.english, "go"), .forgot, returnLap: 9)
        let again = try UserStore(path: path)
        #expect(try again.memory(key) == memory)
        #expect(try again.recalls().count == 2)
        #expect(try again.marks()[WordKey(.english, "go")] == Mark(isHard: true, returnLap: 0))
    }
}
