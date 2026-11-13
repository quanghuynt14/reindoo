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
        }
    }

    /// Le nom tel qu'il s'insère dans une phrase.
    private func languageInline(_ language: Language) -> String {
        switch language {
        case .french: pick("French", "français", "tiếng Pháp")
        case .english: pick("English", "anglais", "tiếng Anh")
        }
    }

    public var allLanguages: String { pick("All languages", "Toutes les langues", "Mọi ngôn ngữ") }

    // MARK: Onglets

    public var tabSearch: String { pick("Dictionary", "Dictionnaire", "Từ điển") }
    public var tabReview: String { pick("Reels", "Reels", "Lướt ôn") }
    public var tabHistory: String { pick("History", "Historique", "Lịch sử") }

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
    public var openEntry: String { pick("Open the entry", "Ouvrir l'entrée", "Xem cả mục từ") }
    public var sortTitle: String { pick("Order", "Ordre", "Sắp xếp") }
    public var filterTitle: String { pick("Filter by language", "Filtrer par langue", "Lọc theo ngôn ngữ") }
    public var sortRandom: String { pick("Random", "Aléatoire", "Ngẫu nhiên") }
    public var sortNewest: String { pick("Newest first", "Récents d'abord", "Mới nhất trước") }
    public var sortOldest: String { pick("Oldest first", "Anciens d'abord", "Cũ nhất trước") }

    public var quizPrompt: String { pick("What does it mean?", "Que veut dire ce mot ?", "Từ này nghĩa là gì?") }
    public var newWord: String { pick("New word", "Nouveau mot", "Từ mới") }
    public func streak(_ count: Int) -> String {
        pick("\(count) words in a row", "\(count) mots d'affilée", "\(count) từ liên tiếp")
    }
    public var like: String { pick("Like", "Aimer", "Thích") }
    public var listen: String { pick("Listen", "Écouter", "Nghe") }
    public var readAloud: String { pick("Read words aloud", "Lire les mots à voix haute", "Đọc to từng từ") }
    public var options: String { pick("Options", "Options", "Tuỳ chọn") }

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
