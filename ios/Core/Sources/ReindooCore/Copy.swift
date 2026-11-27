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
    /// Quand l'entrée mêle deux langues de glose, chaque partie dit la sienne.
    public func wiktionarySenses(in language: Language) -> String {
        "\(wiktionarySenses) · \(languageInline(language))"
    }
    /// L'étiquette courte devant une ligne de glose : « EN », « FR », « VI ».
    /// Un code, pas un mot : il se lit pareil dans les trois interfaces.
    public func languageTag(_ language: Language) -> String {
        switch language {
        case .french: "FR"
        case .english: "EN"
        case .vietnamese: "VI"
        }
    }

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
            "Before a hard conversation, or after an argument: pick the moment that looks like yours.",
            "Avant une conversation difficile, ou après une dispute : choisissez le moment qui ressemble au vôtre.",
            "Trước một cuộc nói chuyện khó, hay sau một trận cãi nhau: hãy chọn khoảnh khắc giống với bạn."
        )
    }

    /// Les quatre cartes du premier passage : qui sont les deux voix, et
    /// pourquoi personne ne sera noté.
    public var talkWelcome: [String] {
        [
            pick(
                "Everyone has two voices. The jackal judges: « Tu es toujours en retard ! » The giraffe says what is going on inside: « J'étais inquiète, je t'attendais. »",
                "Chacun a deux voix. Le chacal juge : « Tu es toujours en retard ! » La girafe dit ce qui se passe en elle : « J'étais inquiète, je t'attendais. »",
                "Ai cũng có hai giọng nói. Chó rừng phán xét: « Tu es toujours en retard ! » Hươu nói điều đang diễn ra bên trong: « J'étais inquiète, je t'attendais. »"
            ),
            pick(
                "The jackal isn't bad. He is hurt or tired, and he shouts because something he needs is missing. Here nobody chases him away: the giraffe listens to him and finds that need.",
                "Le chacal n'est pas méchant. Il est blessé ou fatigué, et il crie parce qu'il lui manque quelque chose. Ici, personne ne le chasse : la girafe l'écoute et trouve ce besoin.",
                "Chó rừng không xấu. Nó bị tổn thương hoặc mệt mỏi, và nó la lên vì đang thiếu một điều nó cần. Ở đây không ai đuổi nó đi: hươu lắng nghe nó và tìm ra nhu cầu ấy."
            ),
            pick(
                "There are no grades here. Each answer shows you something: what the jackal meant, and the French the giraffe uses to say it. Take your time, skip what you like.",
                "Ici, pas de note. Chaque réponse vous montre quelque chose : ce que le chacal voulait dire, et le français que la girafe emploie pour le dire. Prenez votre temps, passez ce que vous voulez.",
                "Ở đây không có điểm số. Mỗi câu trả lời cho bạn thấy một điều: chó rừng thật ra muốn nói gì, và tiếng Pháp mà hươu dùng để nói điều đó. Cứ thong thả, muốn bỏ qua câu nào cũng được."
            ),
            pick(
                "When to come here? Before a hard conversation, after an argument, or when something keeps going round in your head. Pick the situation that looks like yours.",
                "Quand venir ici ? Avant une conversation difficile, après une dispute, ou quand quelque chose vous tourne dans la tête. Choisissez la situation qui ressemble à la vôtre.",
                "Khi nào thì vào đây? Trước một cuộc nói chuyện khó, sau một trận cãi nhau, hay khi có điều gì cứ lởn vởn trong đầu. Hãy chọn tình huống giống với bạn."
            ),
        ]
    }
    public var talkWelcomeTitle: String { pick("Two voices", "Les deux voix", "Hai giọng nói") }
    public var talkWelcomeLength: String { pick("1 min, to start", "1 min, pour commencer", "1 phút, để bắt đầu") }
    public var talkWelcomeDone: String { pick("Choose a situation", "Choisir une situation", "Chọn một tình huống") }

    public func intent(_ intent: Intent) -> (title: String, when: String) {
        switch intent {
        case .feel: (
            pick("Knowing what I feel", "Savoir ce que je ressens", "Hiểu mình đang cảm thấy gì"),
            pick("When something is bothering you, before you talk about it.", "Quand quelque chose vous travaille, avant d'en parler.", "Khi có điều gì làm bạn bận lòng, trước khi nói ra.")
        )
        case .reproach: (
            pick("Saying what's wrong", "Dire ce qui ne va pas", "Nói ra điều không ổn"),
            pick("When someone annoys you and you want to say it without hurting.", "Quand quelqu'un vous agace et que vous voulez le dire sans blesser.", "Khi ai đó làm bạn bực và bạn muốn nói ra mà không làm tổn thương.")
        )
        case .worry: (
            pick("Saying you're worried", "Dire son inquiétude", "Nói ra nỗi lo"),
            pick("When fear comes out as anger.", "Quand la peur sort en colère.", "Khi nỗi sợ bật ra thành cơn giận.")
        )
        case .ask: (
            pick("Asking for what you need", "Demander ce dont on a besoin", "Đề nghị điều mình cần"),
            pick("When you don't dare to ask.", "Quand vous n'osez pas demander.", "Khi bạn không dám mở lời.")
        )
        case .opinion: (
            pick("Giving your opinion", "Donner son avis", "Nói lên ý kiến"),
            pick("When you disagree, or have something hard to say.", "Quand vous n'êtes pas d'accord, ou que vous avez quelque chose de difficile à dire.", "Khi bạn không đồng ý, hay có điều khó nói.")
        )
        case .help: (
            pick("Being there for someone", "Être là pour quelqu'un", "Ở bên ai đó"),
            pick("When someone is struggling and you want to help.", "Quand quelqu'un va mal et que vous voulez l'aider.", "Khi ai đó đang khó khăn và bạn muốn giúp.")
        )
        case .refuse: (
            pick("Saying no", "Dire non", "Nói không"),
            pick("When you want to refuse without lying or feeling guilty.", "Quand vous voulez refuser sans mentir ni culpabiliser.", "Khi bạn muốn từ chối mà không phải nói dối hay áy náy.")
        )
        case .criticism: (
            pick("Hearing a criticism", "Recevoir une critique", "Đón nhận lời chê"),
            pick("When a remark stings.", "Quand une remarque vous pique.", "Khi một lời nhận xét làm bạn nhói lòng.")
        )
        case .repair: (
            pick("Making amends", "Réparer", "Hàn gắn"),
            pick("When you've hurt someone without meaning to.", "Quand vous avez blessé quelqu'un sans le vouloir.", "Khi bạn vô tình làm ai đó tổn thương.")
        )
        case .hint: (
            pick("Hearing what isn't said", "Entendre ce qui n'est pas dit", "Nghe ra điều không nói"),
            pick("When a remark has a second meaning.", "Quand une remarque a un double sens.", "Khi một câu nói có ẩn ý.")
        )
        case .agree: (
            pick("Getting out of a disagreement", "Sortir d'un désaccord", "Thoát khỏi bất đồng"),
            pick("When you each want something different.", "Quand vous voulez chacun autre chose.", "Khi mỗi người muốn một điều khác nhau.")
        )
        }
    }
    public var talkMix: String { pick("Mixed replay", "Pêle-mêle", "Ôn trộn") }
    public func talkMixLines(_ count: Int) -> String {
        pick("\(count) lines from these stories", "\(count) répliques de ces histoires", "\(count) câu từ các chuyện này")
    }
    public var giraffe: String { pick("Giraffe", "Girafe", "Hươu") }
    public var jackal: String { pick("Jackal", "Chacal", "Chó rừng") }
    public var sortQuestion: String { pick("Giraffe or jackal?", "Girafe ou chacal ?", "Hươu hay chó rừng?") }
    public var sortHint: String { pick("← jackal · giraffe →", "← chacal · girafe →", "← chó rừng · hươu →") }
    public var rewriteQuestion: String { pick("What would the giraffe say?", "Que dirait la girafe ?", "Hươu sẽ nói thế nào?") }
    public var bodyQuestion: String { pick("Where do you feel it?", "Où le sent-on ?", "Cảm thấy ở đâu?") }
    public var needQuestion: String { pick("Which need do they share?", "Quel besoin partagent-ils ?", "Hai bạn chung nhu cầu nào?") }
    public var hintQuestion: String { pick("What's behind it?", "Qu'y a-t-il derrière ?", "Đằng sau câu này là gì?") }
    public var continueHint: String { pick("Swipe up to go on", "Glissez vers le haut pour continuer", "Vuốt lên để đọc tiếp") }
    public var heard: String { pick("Heard", "Bien entendu", "Nghe ra rồi") }
    /// Une réponse à côté n'est pas une faute : on montre ce qu'il fallait entendre.
    public func otherWay(_ kind: Beat.Kind) -> String {
        switch kind {
        case .body: pick("Here's the expression", "Voici l'expression", "Đây là thành ngữ")
        case .need: pick("Here's the need they share", "Voici le besoin commun", "Đây là nhu cầu chung")
        case .hint: pick("Here's what the giraffe hears", "Voici ce qu'entend la girafe", "Đây là điều hươu nghe thấy")
        default: pick("Here's how the giraffe would say it", "Voici comment la girafe le dirait", "Hươu sẽ nói thế này")
        }
    }
    public var giraffeWouldSay: String { pick("The giraffe would say", "La girafe dirait", "Hươu sẽ nói") }
    public var giraffeFrench: String { pick("The giraffe's French", "Le français de la girafe", "Tiếng Pháp của hươu") }
    public var lookUp: String { pick("Look it up", "Voir dans le dictionnaire", "Tra từ điển") }
    public var writeOwn: String { pick("And you, how would you say it?", "Et vous, comment le diriez-vous ?", "Còn bạn, bạn sẽ nói thế nào?") }
    public var writePlaceholder: String { pick("Your line, in French", "Votre phrase, en français", "Câu của bạn, bằng tiếng Pháp") }
    public var keep: String { pick("Keep", "Garder", "Lưu") }
    public var rereadOwn: String { pick("Read your line again:", "Relisez votre phrase :", "Đọc lại câu của bạn:") }
    public func check(_ part: Part) -> String {
        switch part {
        case .observation: pick("I said what happened, without judging", "J'ai dit ce qui s'est passé, sans juger", "Mình đã nói chuyện gì xảy ra, không phán xét")
        case .feeling: pick("I said what I feel", "J'ai dit ce que je ressens", "Mình đã nói mình cảm thấy gì")
        case .need: pick("I said what I need", "J'ai dit ce dont j'ai besoin", "Mình đã nói mình cần gì")
        case .request: pick("I asked for something they can do, or refuse", "J'ai demandé quelque chose de faisable, qu'on peut refuser", "Mình đã đề nghị một việc làm được, và người kia có thể từ chối")
        }
    }
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
    public var pileRight: String { pick("Heard", "Bien entendues", "Đã nghe ra") }
    public var pileWrong: String { pick("To hear again", "À réentendre", "Nghe lại") }
    /// Ni faute ni reproche : une carte passée attend, voilà tout.
    public var pileSkipped: String { pick("Not yet", "Pas encore", "Chưa đến") }
    public var pileOwn: String { pick("In your words", "Avec vos mots", "Bằng lời của bạn") }
    public var formsTitle: String { pick("The giraffe's French in this story", "Le français de la girafe dans cette histoire", "Tiếng Pháp của hươu trong chuyện này") }
    public var playAgain: String { pick("Play again", "Rejouer", "Chơi lại") }
    public var talkReview: String { pick("Lines to hear again", "Répliques à réentendre", "Nghe lại các câu") }
    public func talkReviewCount(_ count: Int) -> String {
        pick(
            count == 1 ? "1 line" : "\(count) lines",
            count == 1 ? "1 réplique" : "\(count) répliques",
            "\(count) câu"
        )
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
