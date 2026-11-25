/// La langue de l'interface. Les gloses, elles, restent en vietnamien : c'est
/// ce que le lexique contient.
public enum UILanguage: String, Codable, Sendable, CaseIterable {
    case english = "en"
    case french = "fr"
    case vietnamese = "vi"

    /// `fr-FR`, `vi_VN`, `en` : seul le début compte. L'anglais par défaut.
    public init(code: String?) {
        let prefix = (code ?? "").lowercased().prefix(2)
        self = UILanguage(rawValue: String(prefix)) ?? .english
    }
}

/// Le texte que l'app affiche, dans la langue de l'interface. Core le pose
/// dans l'état de chaque écran : la vue n'écrit aucun mot elle-même.
public struct Copy: Equatable, Sendable {
    public let ui: UILanguage

    public init(_ ui: UILanguage) {
        self.ui = ui
    }

    private func pick(_ english: String, _ french: String, _ vietnamese: String) -> String {
        switch ui {
        case .english: english
        case .french: french
        case .vietnamese: vietnamese
        }
    }

    // MARK: Langues du dictionnaire

    public func languageShort(_ language: Language) -> String {
        switch language {
        case .french: pick("French", "Français", "Pháp")
        case .english: pick("English", "Anglais", "Anh")
        case .vietnamese: pick("Vietnamese", "Vietnamien", "Việt")
        }
    }

    /// Le nom tel qu'il s'insère dans une phrase.
    private func languageInline(_ language: Language) -> String {
        switch language {
        case .french: pick("French", "français", "tiếng Pháp")
        case .english: pick("English", "anglais", "tiếng Anh")
        case .vietnamese: pick("Vietnamese", "vietnamien", "tiếng Việt")
        }
    }

    public var allLanguages: String { pick("All languages", "Toutes les langues", "Mọi ngôn ngữ") }

    // MARK: Onglets

    public var tabSearch: String { pick("Dictionary", "Dictionnaire", "Từ điển") }
    public var tabReview: String { pick("Reels", "Reels", "Lướt ôn") }
    public var tabHistory: String { pick("History", "Historique", "Lịch sử") }
    public var tabTalk: String { pick("Talk", "Parler", "Giao tiếp") }

    // MARK: Chercher

    public func searchPrompt(_ language: Language) -> String {
        let name = languageInline(language)
        return pick("Look up a \(name) word", "Chercher un mot \(name)", "Tra từ \(name)")
    }

    public var recents: String { pick("Recent", "Récents", "Gần đây") }
    public var searchEmpty: String {
        pick(
            "Type a word to look it up. The dictionary lives on your phone and needs no network.",
            "Tapez un mot pour le chercher. Le dictionnaire est dans le téléphone : pas besoin de réseau.",
            "Gõ một từ để tra. Từ điển nằm sẵn trong máy, không cần mạng."
        )
    }

    // MARK: Une entrée

    public func notFound(_ query: String) -> String {
        pick("No entry for “\(query)”", "Aucune entrée pour « \(query) »", "Không tìm thấy từ “\(query)”")
    }

    public var notFoundHint: String {
        pick(
            "The dictionary is finite and invents nothing. Did you mean:",
            "Le dictionnaire est fini et n'invente rien. Vouliez-vous dire :",
            "Từ điển có hạn, và không bịa nghĩa. Có phải bạn muốn tìm:"
        )
    }

    public var notFoundNoHint: String {
        pick(
            "The dictionary is finite and invents nothing. Check the spelling.",
            "Le dictionnaire est fini et n'invente rien. Vérifiez l'orthographe.",
            "Từ điển có hạn, và không bịa nghĩa. Hãy kiểm tra lại chính tả."
        )
    }

    public func foundElsewhere(_ language: Language) -> String {
        let name = languageInline(language)
        return pick("In the \(name) dictionary", "Dans le dictionnaire \(name)", "Có trong từ điển \(name)")
    }

    public func matchedForm(_ form: String, _ lemma: String) -> String {
        pick("“\(form)” is a form of “\(lemma)”", "« \(form) » est une forme de « \(lemma) »", "“\(form)” là một dạng của “\(lemma)”")
    }

    public var alsoFrom: String { pick("Could also be", "Peut aussi être", "Cũng có thể là") }
    public var synonyms: String { pick("Synonyms", "Synonymes", "Đồng nghĩa") }
    public var antonyms: String { pick("Antonyms", "Antonymes", "Trái nghĩa") }
    public var derived: String { pick("Derived words", "Dérivés", "Từ phái sinh") }
    /// Au-dessus des sens écrits pour l'app, puis de ceux du Wiktionnaire.
    public var ownSenses: String { "Reindoo" }
    public var wiktionarySenses: String { pick("From Wiktionary", "Du Wiktionnaire", "Từ Wiktionary") }

    // MARK: Historique

    public var historyEmpty: String {
        pick(
            "No history yet. Words you look up will appear here.",
            "Pas encore d'historique. Les mots cherchés apparaîtront ici.",
            "Chưa có lịch sử. Các từ bạn tra sẽ nằm ở đây."
        )
    }

    public var missingEntry: String {
        pick("This word is no longer in the dictionary", "Ce mot n'est plus dans le dictionnaire", "Từ này không còn trong từ điển")
    }

    public var remove: String { pick("Delete", "Supprimer", "Xoá") }

    // MARK: Lướt ôn

    public var reviewEmpty: String {
        pick(
            "Nothing to review yet. Look up a few words, then come back.",
            "Rien à réviser pour l'instant. Cherchez quelques mots, puis revenez.",
            "Chưa có gì để ôn. Tra vài từ rồi quay lại đây."
        )
    }

    public var reviewEmptyFiltered: String {
        pick("No words match this filter.", "Aucun mot ne correspond à ce filtre.", "Không có từ nào khớp với bộ lọc.")
    }

    public var revealHint: String { pick("Tap to see the meaning", "Touchez pour voir le sens", "Chạm để xem nghĩa") }
    public var revealWordHint: String { pick("Tap to see the word", "Touchez pour voir le mot", "Chạm để xem từ") }
    public var meaningFirst: String { pick("Show the meaning first", "Le sens d'abord", "Hiện nghĩa trước") }
    public var wordFirst: String { pick("Show the word first", "Le mot d'abord", "Hiện từ trước") }
    public var openEntry: String { pick("Open the entry", "Ouvrir l'entrée", "Xem cả mục từ") }
    public var sortTitle: String { pick("Order", "Ordre", "Sắp xếp") }
    public var filterTitle: String { pick("Filter by language", "Filtrer par langue", "Lọc theo ngôn ngữ") }
    public var sortRandom: String { pick("Random", "Aléatoire", "Ngẫu nhiên") }
    public var sortNewest: String { pick("Newest first", "Récents d'abord", "Mới nhất trước") }
    public var sortOldest: String { pick("Oldest first", "Anciens d'abord", "Cũ nhất trước") }

    public var quizPrompt: String { pick("What does it mean?", "Que veut dire ce mot ?", "Từ này nghĩa là gì?") }
    public var newWord: String { pick("New word", "Nouveau mot", "Từ mới") }
    public var knewIt: String { pick("Got it", "Je sais", "Đã nhớ") }
    public var again: String { pick("Again", "À revoir", "Ôn thêm") }
    public var swipeHint: String { pick("← got it · again →", "← je sais · à revoir →", "← đã nhớ · ôn thêm →") }
    public func streak(_ count: Int) -> String {
        pick("\(count) words in a row", "\(count) mots d'affilée", "\(count) từ liên tiếp")
    }
    public var like: String { pick("Like", "Aimer", "Thích") }
    /// Le bouton au cerveau : ce qui aide à retenir le mot.
    public var memo: String { pick("Remember it", "Pour retenir", "Mẹo nhớ") }
    public var memoOrigin: String { pick("Origin", "Origine", "Nguồn gốc") }
    public var memoRelated: String { pick("Related words", "Mots voisins", "Từ liên quan") }
    public var memoTip: String { pick("Memory tip", "Pour s'en souvenir", "Mẹo nhớ") }
    public var close: String { pick("Close", "Fermer", "Đóng") }
    public var listen: String { pick("Listen", "Écouter", "Nghe") }
    public var readAloud: String { pick("Read words aloud", "Lire les mots à voix haute", "Đọc to từng từ") }
    public var options: String { pick("Options", "Options", "Tuỳ chọn") }
    public var sceneTitle: String { pick("Scene", "Décor", "Cảnh nền") }
    public var scenePerWord: String { pick("One per word", "Un par mot", "Mỗi từ một cảnh") }
    public var sceneColours: String { pick("Plain colours", "Couleurs unies", "Màu trơn") }

    // MARK: Giao tiếp

    public var talkIntro: String {
        pick(
            "The giraffe speaks from the heart: what happened, what I feel, what I need, what I ask. The jackal speaks in judgments. Short animal stories, one line at a time.",
            "La girafe parle avec le cœur : ce qui s'est passé, ce que je ressens, ce dont j'ai besoin, ce que je demande. Le chacal parle en jugements. De courtes histoires d'animaux, une réplique à la fois.",
            "Hươu cao cổ nói bằng trái tim: chuyện gì xảy ra, mình cảm thấy gì, cần gì, đề nghị gì. Chó rừng nói bằng phán xét. Những câu chuyện ngắn về các con vật, từng câu một."
        )
    }
    public var giraffe: String { pick("Giraffe", "Girafe", "Hươu") }
    public var jackal: String { pick("Jackal", "Chacal", "Chó rừng") }
    public var sortQuestion: String { pick("Giraffe or jackal?", "Girafe ou chacal ?", "Hươu hay chó rừng?") }
    public var sortHint: String { pick("← jackal · giraffe →", "← chacal · girafe →", "← chó rừng · hươu →") }
    public var rewriteQuestion: String { pick("What would the giraffe say?", "Que dirait la girafe ?", "Hươu sẽ nói thế nào?") }
    public var bodyQuestion: String { pick("Where do you feel it?", "Où le sent-on ?", "Cảm thấy ở đâu?") }
    public var needQuestion: String { pick("Which need do they share?", "Quel besoin partagent-ils ?", "Hai bạn chung nhu cầu nào?") }
    public var continueHint: String { pick("Swipe up to go on", "Glissez vers le haut pour continuer", "Vuốt lên để đọc tiếp") }
    public var rightAnswer: String { pick("Right", "Juste", "Đúng rồi") }
    public var wrongAnswer: String { pick("Not quite", "Pas tout à fait", "Chưa đúng") }
    public func wasVoice(_ voice: Voice) -> String {
        switch voice {
        case .giraffe: pick("It's the giraffe", "C'est la girafe", "Đây là hươu")
        case .jackal: pick("It's the jackal", "C'est le chacal", "Đây là chó rừng")
        }
    }
    public func part(_ part: Part) -> String {
        switch part {
        case .observation: pick("Observation", "Observation", "Quan sát")
        case .feeling: pick("Feeling", "Sentiment", "Cảm xúc")
        case .need: pick("Need", "Besoin", "Nhu cầu")
        case .request: pick("Request", "Demande", "Lời đề nghị")
        }
    }
    public var storyEnd: String { pick("End of the story", "Fin de l'histoire", "Hết chuyện") }
    public var pileRight: String { pick("Right", "Justes", "Đúng") }
    public var pileWrong: String { pick("Missed", "Ratées", "Sai") }
    public var pileSkipped: String { pick("Passed without answering", "Passées sans répondre", "Lướt qua chưa trả lời") }
    public var skippedNote: String {
        pick(
            "A card you pass is not a mistake. But a line you avoid here is one you'll avoid when you speak.",
            "Une carte passée n'est pas une faute. Mais une réplique évitée ici, on l'évitera aussi en parlant.",
            "Lướt qua không phải là sai. Nhưng câu nào né ở đây thì khi nói thật cũng sẽ né."
        )
    }
    public var playAgain: String { pick("Play again", "Rejouer", "Chơi lại") }
    public var talkReview: String { pick("Lines to review", "Répliques à revoir", "Ôn lại câu sai") }
    public func talkReviewCount(_ count: Int) -> String {
        pick(
            count == 1 ? "1 line you missed" : "\(count) lines you missed",
            count == 1 ? "1 réplique ratée" : "\(count) répliques ratées",
            "\(count) câu bạn trả lời sai"
        )
    }
    public func talkScore(_ right: Int, _ total: Int) -> String {
        pick("\(right)/\(total) right", "\(right)/\(total) justes", "Đúng \(right)/\(total)")
    }
    public func talkLines(_ total: Int) -> String {
        pick("\(total) lines", "\(total) répliques", "\(total) câu")
    }

    // MARK: L'app

    public var lexiconUnavailable: String {
        pick("The dictionary could not be opened", "Le dictionnaire ne s'ouvre pas", "Không mở được từ điển")
    }

    public func pending(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return pick(
            count == 1 ? "1 change waiting to sync" : "\(count) changes waiting to sync",
            count == 1 ? "1 changement à synchroniser" : "\(count) changements à synchroniser",
            "\(count) thay đổi đang chờ đồng bộ"
        )
    }
}
