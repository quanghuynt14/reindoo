import Foundation
import Testing
@testable import ReindooCore

/// Reindoo Hán Việt : le chinois expliqué en vietnamien, le vietnamien expliqué en
/// chinois. Le même code que reindoo ; seule l'édition change.
@MainActor
@Suite struct HanEdition {
    private func han(_ fixture: Fixture = .sample) throws -> Harness {
        try Harness(fixture, edition: .han)
    }

    private func encoded(_ text: String) throws -> String {
        String(decoding: try JSONEncoder().encode(["text": text]), as: UTF8.self)
    }

    @Test func theEditionComesFromItsNameAndDefaultsToReindoo() {
        #expect(Edition(name: nil) == .reindoo)
        #expect(Edition(name: "") == .reindoo)
        #expect(Edition(name: "han") == .han)
        #expect(Edition(name: "klingon") == .reindoo)
        #expect(Edition.reindoo.languages == [.french, .english, .vietnamese])
        #expect(Edition.han.languages == [.chinese, .vietnamese])
    }

    @Test func reindooStillOffersItsThreeLanguagesFrenchFirst() throws {
        let app = try Harness()
        #expect(try app.state("language") == "french")
        #expect((try app.state("languages", as: [Any].self))?.count == 3)
        #expect(app.app.languages == [.french, .english, .vietnamese])
    }

    @Test func hanOffersChineseThenVietnameseAndNothingElse() throws {
        let app = try han()
        #expect(try app.state("language") == "chinese")
        #expect((try app.state("languages", as: [Any].self))?.count == 2)
        #expect(try app.state("languages.0.label") == Harness.copy.languageShort(.chinese))
        #expect(try app.state("languages.1.label") == Harness.copy.languageShort(.vietnamese))
        #expect(try app.state("prompt") == Harness.copy.searchPrompt(.chinese))
        #expect(throws: IntrospectionError.self) { try app.do("setLanguage", #"{"name":"french"}"#) }
    }

    @Test func theLabelsExistInTheThreeInterfaceLanguages() {
        #expect(Copy(.english).languageShort(.chinese) == "Chinese")
        #expect(Copy(.french).languageShort(.chinese) == "Chinois")
        #expect(Copy(.vietnamese).languageShort(.chinese) == "Trung")
        #expect(Copy(.french).searchPrompt(.chinese) == "Chercher un mot chinois")
        #expect(Copy(.vietnamese).hanViet(["nhĩ hảo"]) == "Hán Việt: nhĩ hảo")
    }

    @Test func chineseIsReadWithAChineseVoice() {
        #expect(Language.chinese.speechCode == "zh-CN")
        #expect(Language.vietnamese.speechCode == "vi-VN")
    }

    @Test func aWordInCharactersShowsItsPinyinAndItsHanVietReading() throws {
        let app = try han()
        try app.search("你好")
        #expect(try app.screen == "entry")
        #expect(try app.state("word") == "你好")
        #expect(try app.state("ipa") == "nǐ hǎo")
        #expect(try app.state("hanViet") == Harness.copy.hanViet(["nhĩ hảo"]))
        #expect(try app.state("translated") == "xin chào")
        #expect(try app.state("senses.0.examples.0.sourceSentence") == "你好，我是老师。")
        // Venu du Wiktionnaire vietnamien : l'adresse est gardée telle quelle.
        #expect(try app.state("wiki") == "https://vi.wiktionary.org/wiki/%E4%BD%A0%E5%A5%BD#Ti%E1%BA%BFng_Quan_Tho%E1%BA%A1i")
        #expect(try app.state("traditional", as: String.self) == nil, "même graphie : rien à montrer")
    }

    @Test func theTraditionalSpellingAndTheExamplePinyinAreShown() throws {
        let app = try han()
        try app.search("学生")
        #expect(try app.state("traditional") == Harness.copy.traditional("學生"))
        #expect(try app.state("senses.0.examples.0.pinyin") == "Wǒ shì xuésheng.")
        #expect(try app.state("senses.0.examples.0.targetTranslation") == "Tôi là học sinh.")
        // Venu du Wiktionnaire anglais : l'adresse se déduit, rien n'est rangé.
        #expect(try app.state("wiki") == "https://en.wiktionary.org/wiki/%E5%AD%A6%E7%94%9F#Chinese")
    }

    @Test func aDeducibleChineseAddressIsNotStored() throws {
        let entry = Entry(word: "学生", language: .chinese, translated: "học sinh",
                          wiki: "https://en.wiktionary.org/wiki/%E5%AD%A6%E7%94%9F#Chinese", traditional: "學生")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let body = String(decoding: try encoder.encode(Packed(entry)), as: UTF8.self)
        #expect(body == #"{"c":"學生","t":"học sinh"}"#)
        #expect(Packed(entry).entry(word: "学生", language: .chinese) == entry)
    }

    @Test func aPinyinFieldOfItsOwnIsThePronunciation() throws {
        let app = try han()
        try app.search("汉语")
        #expect(try app.state("ipa") == "hànyǔ")
        #expect(try app.state("hanViet") == Harness.copy.hanViet(["hán ngữ"]))
        #expect(try app.state("traditional") == Harness.copy.traditional("漢語"))
    }

    @Test func aTraditionalCharacterLeadsToTheSimplifiedEntry() throws {
        let app = try han()
        try app.search("漢語")
        #expect(try app.state("word") == "汉语")
        #expect(try app.state("matchedNote") == Harness.copy.matchedForm("漢語", "汉语"))
    }

    @Test(arguments: ["nǐ hǎo", "ni hao", "nihao", "Ni Hao", "ni3 hao3", "ni'hao"])
    func pinyinWrittenAnyWayFindsTheWord(_ typed: String) throws {
        let app = try han()
        try app.search(typed)
        #expect(try app.state("word") == "你好")
        #expect(try app.state("matchedNote", as: String.self) == nil, "une lecture n'est pas « une forme de »")
    }

    @Test func pinyinWithoutTonesOpensTheCommonestCharacterAndListsTheOthers() throws {
        let app = try han()
        try app.search("shi")
        #expect(try app.state("word") == "是")
        #expect(try app.state("alsoFrom") == ["十", "事"])
    }

    @Test func aTypedToneIsAChoice() throws {
        let app = try han()
        try app.search("shí")
        #expect(try app.state("word") == "十")
    }

    @Test func üCanBeTypedAsVOrU() throws {
        for typed in ["nǚ", "nv", "nu"] {
            let app = try han()
            try app.search(typed)
            #expect(try app.state("word") == "女", "\(typed)")
        }
    }

    @Test func aPinyinFormFromTheSourceIsFoundToo() throws {
        let app = try han()
        try app.search("hàn yǔ")
        #expect(try app.state("word") == "汉语")
    }

    @Test func completionsFollowThePinyinTypedSoFar() throws {
        let app = try han()
        try app.do("setQuery", try encoded("nih"))
        #expect(try app.state("completions") == ["你好"])
        try app.do("setQuery", try encoded("sh"))
        #expect(try app.state("completions") == ["是", "十", "事"])
        try app.do("setQuery", try encoded("你"))
        #expect(try app.state("completions") == ["你好"])
    }

    @Test func vietnameseIsExplainedInChineseAndKeepsItsBareTypingRule() throws {
        let app = try han()
        try app.do("setLanguage", #"{"name":"vietnamese"}"#)
        try app.search("an")
        #expect(try app.state("word") == "ăn")
        #expect(try app.state("translated") == "吃")
        #expect(try app.state("alsoFrom") == ["an"])
    }

    @Test func aVietnameseWordTypedOnTheChineseSideIsFoundElsewhere() throws {
        let app = try han()
        try app.search("học sinh")
        #expect(try app.state("status") == "notFound")
        #expect(try app.state("elsewhere.0.language") == "vietnamese")
        #expect(try app.state("elsewhere.0.translated") == "学生")
        #expect((try app.state("elsewhere", as: [Any].self))?.count == 1, "pas de français ni d'anglais dans Hán")
    }

    @Test func theReelFiltersOnlyOfferTheEditionsLanguages() throws {
        let app = try han(.returning)
        try app.do("selectTab", #"{"name":"review"}"#)
        let filters = try app.state("filters", as: [[String: Any]].self)
        #expect(filters?.compactMap { $0["name"] as? String } == ["all", "chinese", "vietnamese"])
        #expect((try app.state("cards", as: [Any].self))?.isEmpty == false)
    }

    @Test func historyKeepsChineseWords() throws {
        let app = try han(.returning)
        try app.do("selectTab", #"{"name":"history"}"#)
        #expect(try app.state("items.0.word") == "你好")
        #expect(try app.state("items.0.languageLabel") == Harness.copy.languageShort(.chinese))
    }

    @Test func withoutTheVietnameseChineseFileOnlyChineseIsOffered() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("reindoo-han-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let chineseOnly = Fixture.hanSampleNDJSON.split(separator: "\n").filter { $0.contains(#""sourceLanguage":"chinese""#) }.joined(separator: "\n")
        let report = try LexiconBuilder.build(ndjson: [chineseOnly], to: path)
        #expect(report.entries == 8)
        #expect(report.forms == 3)
        let app = AppModel(lexicon: try Lexicon(path: path), user: try UserStore(path: ":memory:"), copy: Harness.copy, edition: .han)
        #expect(app.languages == [.chinese])
    }

    @Test func theBuilderTakesTheChineseAndVietnameseChineseFilesSeparately() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("reindoo-han2-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let lines = Fixture.hanSampleNDJSON.split(separator: "\n")
        let zh = lines.filter { $0.contains(#""sourceLanguage":"chinese""#) }.joined(separator: "\n")
        let vi = lines.filter { $0.contains(#""sourceLanguage":"vietnamese""#) }.joined(separator: "\n")
        let report = try LexiconBuilder.build(ndjson: [zh, vi], to: path)
        #expect(report == LexiconBuilder.Report(entries: 11, forms: 3, skipped: 0))
        let lexicon = try Lexicon(path: path)
        #expect(try lexicon.count(.chinese) == 8)
        #expect(try lexicon.count(.vietnamese) == 3)
        #expect(try lexicon.count(.french) == 0)
    }

    @Test func aReindooEntryIsPackedExactlyAsBefore() throws {
        let entry = Entry(word: "aller", language: .french, translated: "đi", ipa: ["/a.le/"])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let body = String(decoding: try encoder.encode(Packed(entry)), as: UTF8.self)
        #expect(body == #"{"i":["/a.le/"],"n":true,"t":"đi"}"#)
    }
}

@Suite struct HanText {
    @Test func foldingLeavesCharactersAlone() {
        #expect(Text.fold("漢語") == "漢語")
        #expect(Text.fold("你好") == "你好")
        #expect(Text.fold("Nǐ Hǎo") == "ni hao")
    }

    @Test func thePinyinKeyDropsTonesSpacesAndNumbers() {
        #expect(Text.pinyinKey("nǐ hǎo") == "nihao")
        #expect(Text.pinyinKey("ni3 hao3") == "nihao")
        #expect(Text.pinyinKey("Xī'ān") == "xian")
        #expect(Text.pinyinKey("lǜ") == "lu")
        #expect(Text.pinyinKey("lv") == "lu")
        #expect(Text.pinyinKey("你好") == nil)
        #expect(Text.pinyinKey("/ni˨˩˦/") == nil)
        #expect(Text.pinyinKey("") == nil)
    }

    @Test func theToneKeyKeepsTonesOnly() {
        #expect(Text.toneKey("nǐ hǎo") == "nǐhǎo")
        #expect(Text.toneKey("ni hao") == nil)
        #expect(Text.toneKey("ni3") == nil)
        #expect(Text.toneKey("你好") == nil)
    }

    @Test func charactersAreTellable() {
        #expect(Text.hasHanzi("漢語"))
        #expect(!Text.hasHanzi("hànyǔ"))
        #expect(!Text.hasHanzi("học sinh"))
    }
}
