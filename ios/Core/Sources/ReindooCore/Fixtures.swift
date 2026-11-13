import Foundation

/// Des mondes de départ, pour le CLI, les tests et les aperçus.
/// Aucun ne touche le réseau.
public enum Fixture: String, Sendable, CaseIterable {
    /// Un petit lexique, pas de passé.
    case sample
    /// Le même, avec un historique.
    case returning

    /// Quelques lignes au format du dépôt `dictionnaire` : assez pour couvrir
    /// la vedette, la forme fléchie ambiguë, le renvoi, et l'accent oublié.
    public static let sampleNDJSON = #"""
    {"_collection":"dictionary","word":"aller","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"đi","rank":980,"ipa":["/a.le/"],"wiki":"https://vi.wiktionary.org/wiki/aller","derived":["allée","s'en aller"],"explains":[{"explain":"Đi, di chuyển từ nơi này đến nơi khác.","synonyms":["se rendre"],"antonyms":["venir","rester"],"exampleSentences":[{"sourceSentence":"Je vais à l'école.","targetTranslation":"Tôi đi học."}]},{"explain":"Hợp, vừa.","synonyms":["convenir"],"antonyms":[],"exampleSentences":[{"sourceSentence":"Cette robe te va bien.","targetTranslation":"Cái váy này hợp với bạn."}]}]}
    {"_collection":"dictionary","word":"allier","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"kết hợp","rank":310,"ipa":["/a.lje/"],"explains":[{"explain":"Kết hợp, liên kết.","synonyms":["unir"],"antonyms":[],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"allée","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"lối đi","rank":420,"ipa":["/a.le/"],"explains":[{"explain":"Lối đi, đường có hàng cây.","synonyms":[],"antonyms":[],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"allumer","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"bật, thắp","rank":510,"explains":[{"explain":"Bật (đèn), thắp (lửa).","synonyms":[],"antonyms":["éteindre"],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"élève","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"học sinh","rank":700,"ipa":["/e.lɛv/"],"explains":[{"explain":"Học sinh, học trò.","synonyms":["écolier"],"antonyms":[],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"élever","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"nuôi, nâng lên","rank":640,"explains":[{"explain":"Nuôi dạy; nâng lên.","synonyms":[],"antonyms":["abaisser"],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"venir","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"đến","rank":960,"explains":[{"explain":"Đến, tới.","synonyms":["arriver"],"antonyms":["aller"],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"Paris","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"Paris","rank":300,"explains":[{"explain":"Thủ đô nước Pháp.","synonyms":[],"antonyms":[],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"pari","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"sự đánh cuộc","rank":200,"explains":[{"explain":"Sự đánh cuộc.","synonyms":[],"antonyms":[],"exampleSentences":[]}]}
    {"_collection":"dictionary_forms","form":"allions","sourceLanguage":"french","lemmas":["allier","aller"]}
    {"_collection":"dictionary_forms","form":"vais","sourceLanguage":"french","lemmas":["aller"]}
    {"_collection":"dictionary_forms","form":"élève","sourceLanguage":"french","lemmas":["élever"]}
    {"_collection":"dictionary","word":"go","sourceLanguage":"english","targetLanguage":"vietnamese","translated":"đi","rank":990,"ipa":["/ɡəʊ/","/ɡoʊ/"],"explains":[{"explain":"Đi, đi đến.","synonyms":["move"],"antonyms":["come","stay"],"exampleSentences":[{"sourceSentence":"Let's go home.","targetTranslation":"Về nhà thôi."}]}]}
    {"_collection":"dictionary","word":"went","sourceLanguage":"english","targetLanguage":"vietnamese","translated":"quá khứ của go","rank":400,"explains":[{"explain":"Động từ quá khứ của go.","synonyms":[],"antonyms":[],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"gone","sourceLanguage":"english","targetLanguage":"vietnamese","translated":"đã đi","rank":380,"explains":[{"explain":"Đã đi, đã mất.","synonyms":[],"antonyms":[],"exampleSentences":[]}]}
    {"_collection":"dictionary_forms","form":"went","sourceLanguage":"english","lemmas":["go"]}
    {"_collection":"dictionary_forms","form":"goes","sourceLanguage":"english","lemmas":["go"]}
    """#

    /// Construit le monde dans un dossier temporaire et rend l'app prête.
    @MainActor
    public func makeApp(ui: UILanguage = .vietnamese, now: (() -> Date)? = nil) throws -> AppModel {
        // Sans horloge fournie, chaque écriture avance d'une seconde : l'ordre
        // de l'historique ne dépend pas de la vitesse de la machine.
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let now = now ?? {
            clock += 1
            return clock
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("reindoo-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lexiconPath = directory.appendingPathComponent("lexicon.sqlite").path
        _ = try LexiconBuilder.build(ndjson: [Self.sampleNDJSON], to: lexiconPath)

        var tick = 0
        let user = try UserStore(path: ":memory:", now: now, makeID: {
            tick += 1
            return "change-\(tick)"
        })
        if self == .returning {
            try user.remember(WordKey(.french, "élève"))
            try user.remember(WordKey(.french, "venir"))
            try user.remember(WordKey(.english, "go"))
            try user.remember(WordKey(.french, "aller"))
        }
        // Un « hasard » qui se répète : l'ordre alphabétique, que ni « récents »
        // ni « anciens » ne donnent.
        // Le tirage des surprises se répète aussi : toujours le milieu.
        return AppModel(
            lexicon: try Lexicon(path: lexiconPath), user: user, copy: Copy(ui),
            shuffle: { words in words.sorted { Text.fold($0.key.word) < Text.fold($1.key.word) } },
            chance: { $0 / 2 }
        )
    }
}
