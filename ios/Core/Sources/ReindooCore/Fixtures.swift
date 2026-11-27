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
    /// Les lignes vietnamiennes sont celles du vrai lexique, abrégées : un mot
    /// tapé sans accents (« an »), un « đ », l'autre place du ton (« hoà »),
    /// et des sens que seul le Wiktionnaire anglais donne, marqués [EN].
    public static let sampleNDJSON = #"""
    {"_collection":"dictionary","word":"aller","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"đi","rank":980,"ipa":["/a.le/"],"wiki":"https://vi.wiktionary.org/wiki/aller","derived":["allée","s'en aller"],"explains":[{"explain":"Đi, di chuyển từ nơi này đến nơi khác.","synonyms":["se rendre"],"antonyms":["venir","rester"],"exampleSentences":[{"sourceSentence":"Je vais à l'école.","targetTranslation":"Tôi đi học."}]},{"explain":"Hợp, vừa.","synonyms":["convenir"],"antonyms":[],"exampleSentences":[{"sourceSentence":"Cette robe te va bien.","targetTranslation":"Cái váy này hợp với bạn."}]},{"explain":"(Động từ) [EN] to go; to move","synonyms":[],"antonyms":[],"exampleSentences":[{"sourceSentence":"Je vais à Paris.","targetTranslation":"I'm going to Paris."}]},{"explain":"(Động từ) [EN] to be (of health)","synonyms":[],"antonyms":[],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"allier","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"kết hợp","rank":310,"ipa":["/a.lje/"],"explains":[{"explain":"Kết hợp, liên kết.","synonyms":["unir"],"antonyms":[],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"allée","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"lối đi","rank":420,"ipa":["/a.le/"],"explains":[{"explain":"Lối đi, đường có hàng cây.","synonyms":[],"antonyms":[],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"allumer","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"bật, thắp","rank":510,"explains":[{"explain":"Bật (đèn), thắp (lửa).","synonyms":[],"antonyms":["éteindre"],"exampleSentences":[]}]}
    {"_collection":"dictionary","word":"élève","sourceLanguage":"french","targetLanguage":"vietnamese","translated":"học sinh","rank":700,"ipa":["/e.lɛv/"],"explains":[{"explain":"Học sinh, học trò.","synonyms":["écolier"],"antonyms":[],"exampleSentences":[]}],"memo":{"origin":"Từ động từ *élever*, **nâng lên, nuôi dạy**.","tip":"Người được nâng lên.","related":"  "}}
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
    {"_collection":"dictionary","word":"ăn","sourceLanguage":"vietnamese","targetLanguage":"french","translated":"Manger / Bénéficier (d’un avantage) / Valoir","explains":[{"explain":"(Verbe) Manger.","synonyms":[],"antonyms":[],"exampleSentences":[]},{"explain":"(Verbe) Consommer.","synonyms":[],"antonyms":[],"exampleSentences":[]},{"explain":"(Verbe) Absorber.","synonyms":[],"antonyms":[],"exampleSentences":[]}],"ipa":["/an˧˧/"],"wiki":"https://fr.wiktionary.org/wiki/%C4%83n#Vietnamien","rank":29738}
    {"_collection":"dictionary","word":"an","sourceLanguage":"vietnamese","targetLanguage":"french","translated":"En paix, paisible, tranquille, calme","explains":[{"explain":"(Adjectif) En paix, paisible, tranquille, calme.","synonyms":[],"antonyms":[],"exampleSentences":[]},{"explain":"(Adjectif) [EN] calm; peaceful; comfortable; at ease; safe","synonyms":[],"antonyms":[],"exampleSentences":[]}],"ipa":["/an˦/"],"wiki":"https://fr.wiktionary.org/wiki/an#Vietnamien","rank":12812}
    {"_collection":"dictionary","word":"án","sourceLanguage":"vietnamese","targetLanguage":"french","translated":"criminal case / to impede visibility by using the body of something / to camp or station troops in one place","explains":[{"explain":"(Nom) [EN] criminal case","synonyms":[],"antonyms":[],"exampleSentences":[]},{"explain":"(Nom) [EN] sentence (judicial order for punishment)","synonyms":[],"antonyms":[],"exampleSentences":[]},{"explain":"(Nom) [EN] high table with a narrow surface","synonyms":[],"antonyms":[],"exampleSentences":[]}],"ipa":["[ʔaːn˧˦]"],"wiki":"https://en.wiktionary.org/wiki/%C3%A1n#Vietnamese","rank":5997}
    {"_collection":"dictionary","word":"tham nhũng","sourceLanguage":"vietnamese","targetLanguage":"french","translated":"Tracassier et cupide","explains":[{"explain":"(Verbe) Tracassier et cupide.","synonyms":[],"antonyms":[],"exampleSentences":[{"sourceSentence":"quan tham lại nhũng","targetTranslation":"Mandarins cupides et scribes tracassiers."}]},{"explain":"(Verbe) [EN] to be corrupt, to engage in corrupt practices","synonyms":[],"antonyms":[],"exampleSentences":[{"sourceSentence":"quan chức tham nhũng","targetTranslation":"corrupt official(s)"}]},{"explain":"(Nom) [EN] corruption","synonyms":[],"antonyms":[],"exampleSentences":[{"sourceSentence":"chống tham nhũng","targetTranslation":"to fight corruption"}]}],"ipa":["/tʰam˦.ɲuŋˀ˦˧˥/"],"wiki":"https://fr.wiktionary.org/wiki/tham_nh%C5%A9ng#Vietnamien","rank":17}
    {"_collection":"dictionary","word":"nợ","sourceLanguage":"vietnamese","targetLanguage":"french","translated":"debt / to owe","explains":[{"explain":"(Nom) [EN] debt","synonyms":[],"antonyms":[],"exampleSentences":[]},{"explain":"(Verbe) [EN] to owe","synonyms":[],"antonyms":[],"exampleSentences":[]}],"ipa":["[nəː˧˨ʔ]"],"wiki":"https://en.wiktionary.org/wiki/n%E1%BB%A3#Vietnamese","rank":3020}
    {"_collection":"dictionary","word":"hòa","sourceLanguage":"vietnamese","targetLanguage":"french","translated":"in harmony, without conflict / to mix, to mingle","explains":[{"explain":"(Adjectif) [EN] in harmony, without conflict","synonyms":[],"antonyms":[],"exampleSentences":[]},{"explain":"(Adjectif) [EN] tied; deadlocked; stalemated; at a draw","synonyms":[],"antonyms":[],"exampleSentences":[]},{"explain":"(Verbe) [EN] to mix, to mingle","synonyms":[],"antonyms":[],"exampleSentences":[]}],"ipa":["[hwaː˨˩]"],"wiki":"https://en.wiktionary.org/wiki/h%C3%B2a#Vietnamese","rank":3402}
    {"_collection":"dictionary","word":"đẹp","sourceLanguage":"vietnamese","targetLanguage":"french","translated":"beau, joli / bon","explains":[{"explain":"(Adjectif) beau, joli","exampleSentences":[{"sourceSentence":"Cô ấy đẹp lắm.","targetTranslation":"Elle est très belle."}],"note":"Pour un homme, on dit plutôt « đẹp trai ».","source":"reindoo","en":"beautiful, pretty"},{"explain":"(Adjectif) [familier] bon, réussi","source":"reindoo"},{"explain":"(Adjectif) Beau.","synonyms":[],"antonyms":[],"exampleSentences":[]},{"explain":"(Adjectif) [EN] beautiful","synonyms":[],"antonyms":[],"exampleSentences":[]},{"explain":"(Adjectif) [EN] beautiful","synonyms":[],"antonyms":[],"exampleSentences":[]}],"ipa":["[ʔɗɛp̚˧˨ʔ]"],"wiki":"https://fr.wiktionary.org/wiki/%C4%91%E1%BA%B9p#Vietnamien","rank":16033}
    {"_collection":"dictionary_forms","form":"hoà","sourceLanguage":"vietnamese","lemmas":["hòa"],"analysis":"dấu đặt chỗ khác"}
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
