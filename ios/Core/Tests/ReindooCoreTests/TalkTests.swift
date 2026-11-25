import Foundation
import Testing
@testable import ReindooCore

@MainActor
@Suite struct Talk {
    @Test func theTabListsEveryStoryUnplayed() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        #expect(try app.screen == "talk")
        let rows = try #require(try app.state("stories", as: [[String: Any]].self))
        #expect(rows.count == Story.all.count, "pas de « à revoir » avant la première faute")
        #expect(rows.first?["title"] as? String == "Encore en retard")
        #expect(rows.first?["score"] as? String == Harness.copy.talkLines(6))
    }

    @Test func aSortedLineIsCommittedAndExplained() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        try app.do("open", #"{"name":"late"}"#)
        #expect(try app.screen == "story")
        #expect(try app.state("player.cards.0.kind") == "narration")

        try app.do("setPosition", #"{"index":1}"#)
        // « Tu es toujours en retard » : c'est le chacal.
        try app.do("sort", #"{"name":"giraffe"}"#)
        #expect(try app.state("player.cards.1.verdict") == "wrong")
        #expect(try app.state("player.cards.1.sorted") == "giraffe")
        #expect(try app.state("player.cards.1.part") == Harness.copy.part(.observation))

        // On ne reprend pas un tour.
        try app.do("sort", #"{"name":"jackal"}"#)
        #expect(try app.state("player.cards.1.verdict") == "wrong")
        #expect(try app.state("player.cards.1.sorted") == "giraffe")
    }

    @Test func theReportKeepsThreePiles() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        try app.do("open", #"{"name":"late"}"#)
        try app.do("setPosition", #"{"index":1}"#)
        try app.do("sort", #"{"name":"jackal"}"#)
        try app.do("setPosition", #"{"index":2}"#)
        try app.do("sort", #"{"name":"jackal"}"#)

        let cards = try #require(try app.state("player.cards", as: [[String: Any]].self))
        let last = cards.count - 1
        #expect(try app.state("player.cards.\(last).kind") == "report")
        #expect(try app.state("player.cards.\(last).report.right.lines", as: [String].self)?.count == 1)
        #expect(try app.state("player.cards.\(last).report.wrong.lines", as: [String].self)?.count == 1)
        // Quatre répliques passées sans réponse : elles ne sont pas des fautes,
        // mais le bilan les compte.
        #expect(try app.state("player.cards.\(last).report.skipped.lines", as: [String].self)?.count == 4)
    }

    @Test func aMissedLineComesBackInReview() throws {
        let app = try Harness()
        let queued = try app.app.user.pendingCount()
        try app.do("selectTab", #"{"name":"talk"}"#)
        try app.do("open", #"{"name":"late"}"#)
        try app.do("setPosition", #"{"index":1}"#)
        try app.do("sort", #"{"name":"giraffe"}"#)
        try app.do("close")

        #expect(try app.state("stories.0.id") == TalkViewModel.reviewID)
        #expect(try app.state("stories.1.score") == Harness.copy.talkScore(0, 6))
        #expect(try app.app.user.pendingCount() == queued, "les réponses restent sur l'appareil")

        try app.do("open", #"{"name":"review"}"#)
        #expect(try app.state("player.cards.0.id") == "late.1")
        #expect(try app.state("player.cards.0.verdict", as: String.self) == nil, "on la rejoue de zéro")
        try app.do("sort", #"{"name":"jackal"}"#)
        try app.do("close")
        #expect(try app.state("stories.0.id") == "late", "plus rien à revoir")
    }

    @Test func aRewriteIsRightOnlyForTheGiraffe() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        try app.do("open", #"{"name":"dishes"}"#)
        let cards = try #require(try app.state("player.cards", as: [[String: Any]].self))
        let index = try #require(cards.firstIndex { $0["kind"] as? String == "rewrite" })
        let choices = try #require(cards[index]["choices"] as? [[String: Any]])
        let right = try #require(choices.firstIndex { $0["isRight"] as? Bool == true })
        try app.do("setPosition", #"{"index":\#(index)}"#)
        try app.do("choose", #"{"index":\#(right)}"#)
        #expect(try app.state("player.cards.\(index).verdict") == "right")
        #expect(try app.state("player.cards.\(index).picked") == right)
    }

    @Test func theBodyCardShowsTheWholeExpressionOnceAnswered() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        try app.do("open", #"{"name":"body"}"#)
        try app.do("setPosition", #"{"index":1}"#)
        #expect(try app.state("player.cards.1.kind") == "body")
        #expect(try app.state("player.cards.1.text") == "J'ai une boule dans ___.")
        let choices = try #require(try app.state("player.cards.1.choices", as: [[String: Any]].self))
        let right = try #require(choices.firstIndex { $0["isRight"] as? Bool == true })
        try app.do("choose", #"{"index":\#(right)}"#)
        #expect(try app.state("player.cards.1.verdict") == "right")
        #expect(try app.state("player.cards.1.complete") == "J'ai une boule dans la gorge.")
        #expect(try app.state("player.cards.1.part") == "L'émotion retenue")
    }

    @Test func aNeedCardShowsBothStrategies() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        try app.do("open", #"{"name":"needs"}"#)
        try app.do("setPosition", #"{"index":1}"#)
        #expect(try app.state("player.cards.1.kind") == "need")
        #expect(try app.state("player.cards.1.reply") == "Je préfère rester à la maison, sous la couette.")
        #expect(try app.state("player.cards.1.cast", as: [[String: Any]].self)?.count == 2)
        let choices = try #require(try app.state("player.cards.1.choices", as: [[String: Any]].self))
        let wrong = try #require(choices.firstIndex { $0["isRight"] as? Bool == false })
        try app.do("choose", #"{"index":\#(wrong)}"#)
        #expect(try app.state("player.cards.1.verdict") == "wrong")
    }

    /// Le contenu se relit à la main ; ces règles-là se vérifient seules.
    @Test func everyStoryHoldsTogether() {
        var ids = Set<String>()
        for story in Story.all {
            #expect(SceneTheme.named(story.scene) != nil, "\(story.id) : décor inconnu")
            #expect(story.cast.count >= 2)
            for beat in story.beats {
                #expect(ids.insert(beat.id).inserted, "\(beat.id) en double")
                #expect(beat.id.hasPrefix(story.id + "."))
                #expect(!beat.text.isEmpty && !beat.gloss.isEmpty)
                if let speaker = beat.speaker { #expect(story.cast.indices.contains(speaker)) }
                switch beat.kind {
                case .narration: #expect(beat.speaker == nil)
                case .sort: #expect(beat.voice != nil && beat.part != nil && !beat.why.isEmpty)
                case .rewrite, .body, .need:
                    #expect(beat.choices.filter(\.isRight).count == 1, "\(beat.id) : une seule bonne réponse")
                    #expect(beat.choices.allSatisfy { !$0.text.isEmpty && !$0.gloss.isEmpty })
                    #expect(!beat.why.isEmpty)
                }
                if beat.kind == .body {
                    // L'expression entière est la phrase à trous, le trou rempli.
                    let answer = beat.choices.first(where: \.isRight)?.text ?? ""
                    #expect(beat.text.replacingOccurrences(of: "___", with: answer) == beat.complete, "\(beat.id)")
                    #expect(beat.label != nil)
                }
                if beat.kind == .need { #expect(beat.reply != nil && beat.replyGloss != nil) }
            }
            // Une histoire qui fait trier fait trier les deux voix, sinon il
            // suffit de toujours répondre pareil.
            let voices = Set(story.beats.filter { $0.kind == .sort }.compactMap(\.voice))
            #expect(voices.isEmpty || voices == [.giraffe, .jackal], "\(story.id)")
        }
        // La bonne reformulation ne tombe pas toujours au même rang.
        let places = Set(Story.all.flatMap(\.beats).filter { $0.kind == .rewrite }.compactMap {
            TalkViewModel.arranged($0).firstIndex(where: \.isRight)
        })
        #expect(places.count > 1)
    }
}
