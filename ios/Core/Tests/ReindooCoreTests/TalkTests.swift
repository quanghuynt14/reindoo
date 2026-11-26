import Foundation
import Testing
@testable import ReindooCore

@MainActor
@Suite struct Talk {
    @Test func theTabOpensOnTheWelcomeThenSectionsByIntent() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        #expect(try app.screen == "talk")
        #expect(try app.state("sections.0.rows.0.id") == TalkViewModel.welcomeID, "l'accueil en tête, pas imposé")
        let sections = try #require(try app.state("sections", as: [[String: Any]].self))
        #expect(sections.count == Intent.allCases.count + 1)
        #expect(try app.state("sections.1.title") == Harness.copy.intent(.feel).title)
        #expect(try app.state("sections.1.when") == Harness.copy.intent(.feel).when)
        // Dans une intention, l'ordre est celui des chapitres du livre.
        let first = try #require(Story.all.filter { $0.intent == .reproach }.min { $0.chapters[0] < $1.chapters[0] })
        #expect(try app.state("sections.2.rows.0.title") == first.title)
        #expect(try app.state("sections.2.rows.0.detail") == Harness.copy.talkLines(first.questions.count))
        let rows = sections.flatMap { $0["rows"] as? [[String: Any]] ?? [] }
        #expect(rows.count == Story.all.count + 1)
    }

    @Test func theWelcomeIsReadOnceThenMovesDown() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        try app.do("open", #"{"name":"welcome"}"#)
        let cards = try #require(try app.state("player.cards", as: [[String: Any]].self))
        #expect(cards.count == 4, "pas de bilan après l'accueil")
        #expect(try app.state("player.cards.3.done") == Harness.copy.talkWelcomeDone)
        try app.do("close")
        #expect(try app.state("sections.0.id") == Intent.feel.rawValue)
        let sections = try #require(try app.state("sections", as: [[String: Any]].self))
        #expect(try app.state("sections.\(sections.count - 1).rows.0.id") == TalkViewModel.welcomeID)
    }

    @Test func aJackalLineShowsWhatTheGiraffeWouldSay() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        try app.do("open", #"{"name":"late"}"#)
        try app.do("setPosition", #"{"index":1}"#)
        #expect(try app.state("player.cards.1.translation") == "Je t'attends depuis vingt minutes, et c'est la troisième fois ce mois-ci.")
        try app.do("sort", #"{"name":"giraffe"}"#)
        // Pas de « faux » : on dit qui parlait.
        #expect(try app.state("player.cards.1.verdictLabel") == Harness.copy.wasVoice(.jackal))
        let forms = try #require(try app.state("player.cards.1.forms", as: [[String: Any]].self))
        #expect(forms.contains { $0["id"] as? String == "facts" })
    }

    @Test func aWordOpensInTheDictionaryOverTheStory() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        try app.do("lookUp", #"{"word":"besoin"}"#)
        #expect(try app.screen == "talk", "rien à ouvrir hors d'une histoire")
        try app.do("open", #"{"name":"late"}"#)
        try app.do("lookUp", #"{"word":"besoin"}"#)
        #expect(try app.screen == "entry", "l'entrée est par-dessus l'histoire")
        try app.do("closeLookUp")
        #expect(try app.screen == "story")
        #expect(try app.state("player.storyID") == "late", "l'histoire est restée ouverte")
    }

    @Test func aRewriteTakesYourOwnLineAndYourChecks() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        try app.do("open", #"{"name":"late"}"#)
        try app.do("setPosition", #"{"index":6}"#)
        #expect(try app.state("player.cards.6.kind") == "rewrite")
        try app.do("write", #"{"text":"  J'aimerais que tu me préviennes.  "}"#)
        #expect(try app.state("player.cards.6.written") == "J'aimerais que tu me préviennes.")
        try app.do("check", #"{"name":"request"}"#)
        try app.do("check", #"{"name":"feeling"}"#)
        try app.do("check", #"{"name":"request"}"#)
        #expect(try app.state("player.cards.6.checked", as: [String].self) == ["feeling"])
        let last = try #require(try app.state("player.cards", as: [[String: Any]].self)).count - 1
        #expect(try app.state("player.cards.\(last).report.own.lines", as: [String].self) == ["J'aimerais que tu me préviennes."])
        // On la retrouve en rejouant.
        try app.do("replay")
        #expect(try app.state("player.cards.6.written") == "J'aimerais que tu me préviennes.")
    }

    @Test func aMixOpensOnceTwoStoriesOfAnIntentAreDone() throws {
        let app = try Harness()
        try app.do("selectTab", #"{"name":"talk"}"#)
        for id in ["beach", "train"] {
            try app.do("open", #"{"name":"\#(id)"}"#)
            let cards = try #require(try app.state("player.cards", as: [[String: Any]].self))
            for (index, card) in cards.enumerated() {
                try app.do("setPosition", #"{"index":\#(index)}"#)
                switch card["kind"] as? String {
                case "sort": try app.do("sort", #"{"name":"jackal"}"#)
                case "rewrite": try app.do("choose", #"{"index":0}"#)
                default: break
                }
            }
            try app.do("close")
        }
        let sections = try #require(try app.state("sections", as: [[String: Any]].self))
        let worry = try #require(sections.first { $0["id"] as? String == "worry" })
        let rows = try #require(worry["rows"] as? [[String: Any]])
        #expect(rows.last?["id"] as? String == "mix.worry")
        try app.do("open", #"{"name":"mix.worry"}"#)
        let ids = try #require(try app.state("player.cards", as: [[String: Any]].self)).compactMap { $0["id"] as? String }
        let stories = ids.prefix(3).compactMap { $0.split(separator: ".").first.map(String.init) }
        #expect(Set(stories).count == 3, "les histoires alternent")
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

        #expect(try app.state("sections.0.rows.1.id") == TalkViewModel.reviewID)
        #expect(try app.app.user.pendingCount() == queued, "les réponses restent sur l'appareil")

        try app.do("open", #"{"name":"review"}"#)
        #expect(try app.state("player.cards.0.id") == "late.1")
        #expect(try app.state("player.cards.0.verdict", as: String.self) == nil, "on la rejoue de zéro")
        try app.do("sort", #"{"name":"jackal"}"#)
        try app.do("close")
        #expect(try app.state("sections.0.rows", as: [[String: Any]].self)?.count == 1, "plus rien à revoir")
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

    /// Chaque chapitre du livre a sa situation : la progression entière.
    @Test func everyChapterOfTheBookHasAStory() {
        #expect(Set(Story.all.flatMap(\.chapters)) == Set(1...47))
        #expect(Set(Story.all.map(\.id)).count == Story.all.count)
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
                case .rewrite, .body, .need, .hint:
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
        // Chaque histoire montre du français de girafe, sauf celle du corps,
        // qui n'a pas de phrase girafe.
        let model = TalkViewModel(user: try! UserStore(path: ":memory:"), copy: Harness.copy)
        for story in Story.all where story.id != "body" {
            let forms = story.beats.flatMap { model.card($0, in: story).forms }
            #expect(!forms.isEmpty, "\(story.id) : aucune forme girafe")
        }
        // La bonne reformulation ne tombe pas toujours au même rang.
        let places = Set(Story.all.flatMap(\.beats).filter { $0.kind == .rewrite }.compactMap {
            TalkViewModel.arranged($0).firstIndex(where: \.isRight)
        })
        #expect(places.count > 1)
    }
}
