// « Giao tiếp » : des histoires d'animaux où l'on apprend à parler girafe.
//
// La girafe et le chacal viennent de Marshall Rosenberg (la Communication
// NonViolente) : la girafe parle avec le cœur, le chacal parle en jugements.
// « Chacal », pas « loup » : c'est le mot de la CNV en français, celui qu'on
// retrouvera dans les livres et les ateliers.
// Une phrase girafe tient en quatre temps — observation, sentiment, besoin,
// demande — et chaque temps a son piège chacal : le jugement déguisé en fait,
// l'interprétation déguisée en sentiment (« je me sens trahi »), la stratégie
// déguisée en besoin (« j'ai besoin que tu… »), l'exigence déguisée en demande.
//
// Ce que ce fichier reprend de « Communication » dans rappel :
//   - une situation est un dispositif, pas un décor : chaque réplique existe
//     pour un piège précis, et `why` dit lequel ;
//   - l'interlocuteur récite, il ne parle jamais : tout le français affiché est
//     écrit ici, relu, et rien n'est généré sur le téléphone ;
//   - la réponse est engagée : on ne la reprend pas ;
//   - le bilan a trois piles, et la troisième — les cartes passées sans
//     répondre — compte autant que les deux autres.
//
// Les répliques sont originales : aucune ne sort d'un livre. Les gloses et les
// explications sont en vietnamien, comme les sens du dictionnaire.
// Le décor tient au lieu de l'histoire, jamais à la réponse : un décor qui
// changerait avec le verdict le donnerait avant qu'on ait choisi.

/// Les deux façons de parler.
public enum Voice: String, Codable, Sendable, CaseIterable {
    case giraffe
    case jackal
}

/// Les quatre temps d'une phrase girafe.
public enum Part: String, Codable, Sendable, CaseIterable {
    case observation
    case feeling
    case need
    case request
}

/// Un personnage, dessiné à la main ; l'emoji ne sert que si le dessin manque.
public struct Animal: Codable, Equatable, Sendable {
    public var emoji: String
    public var name: String
    /// Son nom en vietnamien.
    public var gloss: String
    /// `giraffe`, `jackal`, ou une espèce de `Species`.
    public var drawing: String? = nil

    /// Son dessin au repos, avant toute réponse.
    public var sketch: Sketch? {
        switch drawing {
        case "giraffe": .giraffe(.calm)
        case "jackal": .jackal(.cross)
        case let name?: Species(rawValue: name).map { .animal($0, .calm) }
        case nil: nil
        }
    }

    static let giraffe = Animal(emoji: "🦒", name: "Girafe", gloss: "Hươu", drawing: "giraffe")
    static let jackal = Animal(emoji: "🐺", name: "Chacal", gloss: "Chó rừng", drawing: "jackal")
}

/// Une proposition de reformulation.
public struct Rewrite: Equatable, Sendable {
    public var text: String
    public var gloss: String
    public var isRight: Bool
}

/// Un moment de l'histoire : un récit, une réplique à trier, une phrase
/// chacal à reformuler, une expression du corps à compléter, ou deux
/// stratégies dont on cherche le besoin commun.
public struct Beat: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case narration, sort, rewrite, body, need, hint }

    public var id: String
    public var kind: Kind
    /// L'indice du personnage qui parle dans `Story.cast`. Aucun pour un récit.
    public var speaker: Int?
    public var text: String
    public var gloss: String
    /// Ce que la réplique est vraiment. Sur une reformulation : chacal.
    public var voice: Voice?
    public var part: Part?
    /// Pourquoi, en vietnamien. Se lit après la réponse.
    public var why: String
    public var choices: [Rewrite]
    /// La réplique du second personnage, sur une carte « besoin ».
    public var reply: String? = nil
    public var replyGloss: String? = nil
    /// L'expression entière, une fois le trou rempli.
    public var complete: String? = nil
    /// Ce que l'expression dit : le sentiment, en français.
    public var label: String? = nil

    static func narration(_ id: String, _ text: String, _ gloss: String) -> Beat {
        Beat(id: id, kind: .narration, speaker: nil, text: text, gloss: gloss, voice: nil, part: nil, why: "", choices: [])
    }

    static func line(_ id: String, _ speaker: Int, _ voice: Voice, _ part: Part, _ text: String, _ gloss: String, why: String) -> Beat {
        Beat(id: id, kind: .sort, speaker: speaker, text: text, gloss: gloss, voice: voice, part: part, why: why, choices: [])
    }

    /// Une expression où le corps parle : on retrouve la partie du corps.
    static func body(_ id: String, _ cloze: String, _ complete: String, _ gloss: String, feeling: String, why: String, _ choices: [Rewrite]) -> Beat {
        Beat(id: id, kind: .body, speaker: nil, text: cloze, gloss: gloss, voice: nil, part: .feeling, why: why, choices: choices, complete: complete, label: feeling)
    }

    /// Deux stratégies, un besoin : on cherche celui qu'elles servent toutes les deux.
    static func need(_ id: String, _ text: String, _ gloss: String, _ reply: String, _ replyGloss: String, why: String, _ choices: [Rewrite]) -> Beat {
        Beat(id: id, kind: .need, speaker: 0, text: text, gloss: gloss, voice: nil, part: .need, why: why, choices: choices, reply: reply, replyGloss: replyGloss)
    }

    /// Une remarque à double sens : on cherche ce que l'autre voudrait au fond.
    static func hint(_ id: String, _ speaker: Int, _ text: String, _ gloss: String, why: String, _ choices: [Rewrite]) -> Beat {
        Beat(id: id, kind: .hint, speaker: speaker, text: text, gloss: gloss, voice: nil, part: .need, why: why, choices: choices)
    }

    static func rewrite(_ id: String, _ speaker: Int, _ text: String, _ gloss: String, why: String, _ choices: [Rewrite]) -> Beat {
        Beat(id: id, kind: .rewrite, speaker: speaker, text: text, gloss: gloss, voice: .jackal, part: .request, why: why, choices: choices)
    }
}

public struct Story: Equatable, Sendable, Identifiable {
    public var id: String
    /// Ce qu'on y apprend à faire : la section de la liste.
    public var intent: Intent
    public var title: String
    public var gloss: String
    /// Un thème de `SceneTheme`, choisi pour le lieu.
    public var scene: String
    public var cast: [Animal]
    public var beats: [Beat]

    /// Les moments qui attendent une réponse.
    public var questions: [Beat] { beats.filter { $0.kind != .narration } }
}

private func giraffe(_ text: String, _ gloss: String) -> Rewrite { Rewrite(text: text, gloss: gloss, isRight: true) }
private func jackal(_ text: String, _ gloss: String) -> Rewrite { Rewrite(text: text, gloss: gloss, isRight: false) }

extension Story {
    /// Les histoires, dans l'ordre où on les propose : par intention, puis
    /// dans chaque intention la plus simple d'abord.
    public static let all: [Story] = [voice, body, late, dishes, meeting, neighbour, hike, beach, train, move, feedback, birthday, hints, needs]

    public static func named(_ id: String) -> Story? { all.first { $0.id == id } }

    static let late = Story(
        id: "late", intent: .reproach, title: "Encore en retard", gloss: "Lại đến muộn", scene: "halftone-dawn",
        cast: [Animal(emoji: "🐻", name: "Ours", gloss: "Gấu", drawing: "bear"), Animal(emoji: "🦔", name: "Hérisson", gloss: "Nhím", drawing: "hedgehog")],
        beats: [
            .narration("late.0",
                       "Ours attend Hérisson au café depuis vingt minutes. C'est la troisième fois ce mois-ci.",
                       "Gấu đợi Nhím ở quán cà phê đã hai mươi phút. Đây là lần thứ ba trong tháng này."),
            .line("late.1", 0, .jackal, .observation,
                  "Tu es toujours en retard, tu te fiches de moi !",
                  "Lúc nào cậu cũng trễ, cậu chẳng coi tớ ra gì!",
                  why: "« Toujours » và « tu te fiches de moi » là phán xét, không phải điều mắt thấy. Người nghe sẽ cãi lại thay vì lắng nghe."),
            .line("late.2", 0, .giraffe, .observation,
                  "Je t'attends depuis vingt minutes, et c'est la troisième fois ce mois-ci.",
                  "Tớ đợi cậu hai mươi phút rồi, và đây là lần thứ ba trong tháng.",
                  why: "Chỉ có sự việc: thời gian, số lần. Một chiếc camera cũng ghi lại được y như vậy."),
            .line("late.3", 0, .jackal, .feeling,
                  "Je me sens méprisé.",
                  "Tớ thấy mình bị coi thường.",
                  why: "« Méprisé » không phải cảm xúc mà là đoán ý người khác: Nhím coi thường mình. Cảm xúc thật có thể là buồn, bực, lo."),
            .line("late.4", 0, .giraffe, .feeling,
                  "Je suis agacé, et un peu triste.",
                  "Tớ bực, và hơi buồn.",
                  why: "Nói điều đang diễn ra trong mình, không đổ lỗi cho ai."),
            .line("late.5", 0, .giraffe, .need,
                  "J'ai besoin de pouvoir compter sur toi quand on se donne rendez-vous.",
                  "Tớ cần tin được vào cậu mỗi khi mình hẹn nhau.",
                  why: "Nhu cầu: được tin cậy. Câu này nói điều Gấu cần, không ra lệnh cho Nhím phải làm gì."),
            .rewrite("late.6", 0,
                     "La prochaine fois, sois à l'heure, sinon je ne viens plus.",
                     "Lần sau đến đúng giờ, không thì tớ không đến nữa.",
                     why: "Lời đề nghị tốt thì cụ thể, làm được, và người kia có quyền nói không. « Sinon je ne viens plus » là lời đe doạ: đó là đòi hỏi.",
                     [
                        giraffe("Si tu vois que tu vas être en retard, tu peux m'envoyer un message avant ?",
                                "Nếu thấy mình sắp trễ, cậu nhắn tin cho tớ trước được không?"),
                        jackal("Tu pourrais faire un effort, quand même.",
                             "Cậu cũng nên cố gắng chút chứ."),
                        jackal("Si tu tenais à moi, tu arriverais à l'heure.",
                             "Nếu quý tớ thì cậu đã đến đúng giờ."),
                     ]),
            .narration("late.7",
                       "Hérisson s'assoit, un peu gêné. « D'accord. La prochaine fois, je t'écris avant. »",
                       "Nhím ngồi xuống, hơi ngượng. « Được. Lần sau tớ sẽ nhắn trước. »"),
        ]
    )

    static let dishes = Story(
        id: "dishes", intent: .reproach, title: "La vaisselle", gloss: "Chồng bát đĩa", scene: "paper-garden-kraft",
        cast: [Animal(emoji: "🐰", name: "Lapine", gloss: "Thỏ", drawing: "rabbit"), Animal(emoji: "🦝", name: "Raton", gloss: "Gấu mèo", drawing: "raccoon")],
        beats: [
            .narration("dishes.0",
                       "Lapine rentre du travail. Dans l'évier, il y a la vaisselle de trois jours. Raton regarde la télé.",
                       "Thỏ đi làm về. Trong bồn rửa là bát đĩa của ba ngày. Gấu mèo đang xem ti vi."),
            .line("dishes.1", 0, .jackal, .observation,
                  "Tu es un vrai cochon.",
                  "Cậu đúng là đồ ở bẩn.",
                  why: "Gán nhãn cho người, không mô tả việc. Bị dán nhãn, ai cũng tự vệ."),
            .line("dishes.2", 0, .giraffe, .observation,
                  "Il y a des assiettes dans l'évier depuis lundi.",
                  "Có bát đĩa trong bồn rửa từ hôm thứ Hai.",
                  why: "Một sự việc ai cũng thấy, có mốc thời gian, không có lời trách."),
            .line("dishes.3", 0, .jackal, .feeling,
                  "Je me sens exploitée.",
                  "Tớ thấy mình bị lợi dụng.",
                  why: "« Exploitée » ngầm buộc tội Gấu mèo. Đó là suy diễn về người kia, không phải cảm xúc."),
            .line("dishes.4", 0, .giraffe, .feeling,
                  "Je suis découragée quand je rentre et que la cuisine est pleine.",
                  "Tớ nản lòng khi về nhà mà bếp thì đầy ắp.",
                  why: "Cảm xúc và hoàn cảnh của nó, không có « tại cậu »."),
            .line("dishes.5", 0, .jackal, .need,
                  "J'ai besoin que tu fasses la vaisselle.",
                  "Tớ cần cậu rửa bát.",
                  why: "Đây là cách giải quyết, không phải nhu cầu. « J'ai besoin que tu… » là một yêu cầu trá hình. Nhu cầu thật có thể là: ngăn nắp, nghỉ ngơi, công bằng."),
            .line("dishes.6", 0, .giraffe, .need,
                  "J'ai besoin d'ordre, et que les tâches soient partagées équitablement.",
                  "Tớ cần sự ngăn nắp, và việc nhà được chia công bằng.",
                  why: "Ngăn nắp và công bằng là nhu cầu chung của mọi người. Gấu mèo có thể hiểu mà không thấy bị trách."),
            .rewrite("dishes.7", 0,
                     "Tu fais la vaisselle ce soir, point final.",
                     "Tối nay cậu rửa bát, hết chuyện.",
                     why: "Lời đề nghị tốt nói rõ việc gì, lúc nào. « Plus responsable » quá mơ hồ: Gấu mèo không biết phải làm gì.",
                     [
                        jackal("Il faudrait que tu sois plus responsable.",
                             "Cậu nên có trách nhiệm hơn."),
                        giraffe("Est-ce que tu serais d'accord pour laver tes assiettes avant 21 heures ?",
                                "Cậu có đồng ý rửa bát của cậu trước 9 giờ tối không?"),
                        jackal("Fais ce que tu veux, de toute façon tu ne m'écoutes jamais.",
                             "Muốn làm gì thì làm, đằng nào cậu cũng chẳng bao giờ nghe tớ."),
                     ]),
        ]
    )

    static let meeting = Story(
        id: "meeting", intent: .reproach, title: "La réunion", gloss: "Buổi họp", scene: "blueprint",
        cast: [Animal(emoji: "🦉", name: "Chouette", gloss: "Cú", drawing: "owl"), Animal(emoji: "🦊", name: "Renard", gloss: "Cáo", drawing: "fox")],
        beats: [
            .narration("meeting.0",
                       "En réunion, Renard présente le plan que Chouette a écrit. Il ne cite pas son nom. Après, elle va le voir.",
                       "Trong buổi họp, Cáo trình bày kế hoạch Cú đã viết mà không nhắc tên cô. Họp xong, cô đến gặp anh."),
            .line("meeting.1", 0, .jackal, .observation,
                  "Tu m'as volé mon idée.",
                  "Anh đã ăn cắp ý tưởng của tôi.",
                  why: "« Volé » là một cách hiểu. Có thể Cáo quên, có thể có hiểu lầm. Bắt đầu bằng sự việc thì cuộc nói chuyện mới mở ra được."),
            .line("meeting.2", 0, .giraffe, .observation,
                  "Pendant la réunion, tu as présenté le plan que j'ai écrit, sans dire qu'il venait de moi.",
                  "Trong buổi họp, anh trình bày kế hoạch tôi viết mà không nói nó là của tôi.",
                  why: "Ai có mặt trong phòng họp cũng xác nhận được câu này."),
            .line("meeting.3", 0, .jackal, .feeling,
                  "Je me sens trahie.",
                  "Tôi thấy mình bị phản bội.",
                  why: "« Trahie » nói về việc người khác đã làm với mình. Cảm xúc thật nằm bên dưới: thất vọng, lo, giận."),
            .line("meeting.4", 0, .giraffe, .feeling,
                  "Je suis déçue, et inquiète pour la suite du projet.",
                  "Tôi thất vọng, và lo cho phần tiếp theo của dự án.",
                  why: "Hai cảm xúc, nói ở ngôi thứ nhất."),
            .line("meeting.5", 0, .giraffe, .need,
                  "J'ai besoin que mon travail soit reconnu.",
                  "Tôi cần công sức của mình được ghi nhận.",
                  why: "Được ghi nhận là nhu cầu. Câu này không chỉ ai phải làm gì: không phải chiến lược."),
            .rewrite("meeting.6", 0,
                     "Tu vas corriger ça tout de suite, devant tout le monde.",
                     "Anh phải sửa ngay chuyện này, trước mặt mọi người.",
                     why: "Một việc cụ thể, Cáo làm được ngay hôm nay, và vẫn có thể từ chối. « Me respecter » là nhu cầu chung chung, không phải hành động.",
                     [
                        jackal("Je voudrais que tu me respectes.",
                             "Tôi muốn anh tôn trọng tôi."),
                        jackal("J'espère que tu es fier de toi.",
                             "Mong là anh thấy tự hào về mình."),
                        giraffe("Est-ce que tu accepterais d'écrire à l'équipe que le plan vient de moi ?",
                                "Anh có đồng ý viết cho cả nhóm rằng kế hoạch là của tôi không?"),
                     ]),
        ]
    )

    static let neighbour = Story(
        id: "neighbour", intent: .reproach, title: "Le voisin du dessus", gloss: "Hàng xóm tầng trên", scene: "braille-stars",
        cast: [Animal(emoji: "🐨", name: "Koala", gloss: "Gấu túi", drawing: "koala"), Animal(emoji: "🐶", name: "Chien", gloss: "Chó", drawing: "dog")],
        beats: [
            .narration("neighbour.0",
                       "Il est une heure du matin. Chez Chien, au-dessus, la musique fait trembler le plafond. Koala monte et frappe à sa porte.",
                       "Một giờ sáng. Nhà Chó ở tầng trên, tiếng nhạc làm rung cả trần. Gấu túi đi lên gõ cửa."),
            .line("neighbour.1", 0, .jackal, .observation,
                  "Vous n'avez aucun respect pour les autres !",
                  "Anh chẳng tôn trọng ai cả!",
                  why: "Một lời phán xét về con người Chó. Anh ấy sẽ bảo vệ mình, không nghĩ đến tiếng nhạc nữa."),
            .line("neighbour.2", 0, .giraffe, .observation,
                  "J'entends votre musique depuis mon lit, et il est une heure du matin.",
                  "Tôi nằm trên giường vẫn nghe thấy nhạc nhà anh, mà bây giờ là một giờ sáng.",
                  why: "Điều tai nghe, giờ đồng hồ chỉ. Không thêm gì."),
            .line("neighbour.3", 0, .jackal, .feeling,
                  "Vous m'énervez.",
                  "Anh làm tôi phát bực.",
                  why: "« Vous m'énervez » đặt cảm xúc của mình lên người khác. Câu hươu: « Je suis énervé », rồi nói vì sao."),
            .line("neighbour.4", 0, .giraffe, .feeling,
                  "Je suis épuisé.",
                  "Tôi kiệt sức rồi.",
                  why: "Một cảm xúc thật, ở ngôi thứ nhất."),
            .line("neighbour.5", 0, .giraffe, .need,
                  "J'ai besoin de dormir : je me lève à six heures.",
                  "Tôi cần ngủ: sáu giờ tôi phải dậy.",
                  why: "Giấc ngủ là nhu cầu ai cũng hiểu, kể cả người đang tổ chức tiệc."),
            .rewrite("neighbour.6", 0,
                     "Baissez le son, ou j'appelle la police.",
                     "Vặn nhỏ nhạc đi, không thì tôi gọi cảnh sát.",
                     why: "« Vous trouvez ça normal ? » không phải câu hỏi mà là lời trách. « Un peu plus calme » quá mơ hồ. Lời đề nghị rõ: làm gì, đến bao giờ.",
                     [
                        jackal("Vous trouvez ça normal ?",
                             "Anh thấy thế này là bình thường à?"),
                        giraffe("Est-ce que vous voudriez bien baisser le son pour le reste de la nuit ?",
                                "Anh có thể vặn nhỏ nhạc cho đến hết đêm nay được không?"),
                        jackal("Ce serait bien d'être un peu plus calme.",
                             "Giá mà yên tĩnh hơn chút thì hay."),
                     ]),
            .narration("neighbour.7",
                       "Chien ouvre de grands yeux. « Une heure ? Je n'avais pas vu. Pardon, je baisse. »",
                       "Chó tròn mắt. « Một giờ rồi á? Tôi không để ý. Xin lỗi, tôi vặn nhỏ đây. »"),
        ]
    )

    static let train = Story(
        id: "train", intent: .worry, title: "Le train annulé", gloss: "Chuyến tàu bị huỷ", scene: "departure-board",
        cast: [Animal(emoji: "🐢", name: "Tortue", gloss: "Rùa", drawing: "turtle"), Animal(emoji: "🦫", name: "Castor", gloss: "Hải ly", drawing: "beaver")],
        beats: [
            .narration("train.0",
                       "Le dernier train pour Lyon est annulé. Tortue arrive au guichet, où travaille Castor.",
                       "Chuyến tàu cuối đi Lyon bị huỷ. Rùa đến quầy vé, nơi Hải ly làm việc."),
            .line("train.1", 0, .jackal, .observation,
                  "Votre compagnie est nulle, comme d'habitude !",
                  "Công ty các anh tệ hại, như mọi khi!",
                  why: "« Nulle » và « comme d'habitude » là phán xét. Hải ly không làm ra lịch tàu, nhưng sẽ phải nghe câu đó."),
            .line("train.2", 0, .giraffe, .observation,
                  "Le train de 21 h 10 est annulé, et l'écran n'indique aucune solution.",
                  "Chuyến 21 giờ 10 bị huỷ, và màn hình không ghi cách nào khác.",
                  why: "Hai sự việc, kiểm chứng được ngay trên bảng giờ."),
            .line("train.3", 0, .jackal, .feeling,
                  "Je me sens abandonnée.",
                  "Tôi thấy mình bị bỏ rơi.",
                  why: "« Abandonnée » nói về việc người khác làm với mình. Bên dưới là cảm xúc thật: lo lắng."),
            .line("train.4", 0, .giraffe, .feeling,
                  "Je suis inquiète : je dois être à Lyon demain à neuf heures.",
                  "Tôi lo lắm: chín giờ sáng mai tôi phải có mặt ở Lyon.",
                  why: "Cảm xúc, và điều gây ra nó, ở ngôi thứ nhất."),
            .line("train.5", 1, .giraffe, .need,
                  "Vous êtes inquiète parce que vous avez besoin d'arriver à l'heure demain, c'est ça ?",
                  "Chị lo vì mai chị cần đến kịp giờ, đúng không ạ?",
                  why: "Hươu cũng biết lắng nghe: Hải ly đoán cảm xúc và nhu cầu của Rùa, rồi hỏi lại cho chắc. Đó là thấu cảm."),
            .rewrite("train.6", 0,
                     "Trouvez-moi un train, c'est votre travail !",
                     "Tìm cho tôi một chuyến tàu đi, việc của anh mà!",
                     why: "Câu hươu hỏi một điều cụ thể mà Hải ly trả lời được. « Faites quelque chose » không nói là việc gì.",
                     [
                        giraffe("Pourriez-vous me dire s'il y a un bus ou un train demain avant sept heures ?",
                                "Anh có thể cho tôi biết có xe buýt hay tàu nào trước bảy giờ sáng mai không?"),
                        jackal("Faites quelque chose, enfin !",
                             "Làm gì đi chứ!"),
                        jackal("Je compte sur vous pour arranger ça.",
                             "Tôi trông cả vào anh để giải quyết đấy."),
                     ]),
        ]
    )

    static let birthday = Story(
        id: "birthday", intent: .repair, title: "L'anniversaire oublié", gloss: "Sinh nhật bị quên", scene: "aurora-snow",
        cast: [Animal(emoji: "🐱", name: "Chat", gloss: "Mèo", drawing: "cat"), Animal(emoji: "🐼", name: "Panda", gloss: "Gấu trúc", drawing: "panda")],
        beats: [
            .narration("birthday.0",
                       "Hier, c'était l'anniversaire de Chat. Panda n'a pas appelé. Ce matin, ils se croisent.",
                       "Hôm qua là sinh nhật Mèo. Gấu trúc không gọi. Sáng nay hai bạn gặp nhau."),
            .line("birthday.1", 0, .jackal, .observation,
                  "Tu ne penses jamais à moi.",
                  "Cậu chẳng bao giờ nghĩ đến tớ.",
                  why: "« Jamais » biến một lần quên thành một bản án. Panda sẽ đi tìm những lần mình đã nhớ."),
            .line("birthday.2", 1, .jackal, .feeling,
                  "Tu exagères, j'avais beaucoup de travail.",
                  "Cậu làm quá rồi, tớ bận việc mà.",
                  why: "Tự bào chữa thì người kia càng thấy không được nghe. Trước khi giải thích, hãy nghe cảm xúc của họ."),
            .line("birthday.3", 1, .giraffe, .feeling,
                  "Tu es triste parce que tu aurais aimé que je pense à toi ?",
                  "Cậu buồn vì muốn tớ nhớ đến cậu, phải không?",
                  why: "Panda đoán cảm xúc và nhu cầu của Mèo, rồi hỏi lại. Lời xin lỗi sẽ dễ nghe hơn sau câu này."),
            .line("birthday.4", 0, .jackal, .need,
                  "J'ai besoin que tu m'offres un cadeau.",
                  "Tớ cần cậu tặng quà cho tớ.",
                  why: "Một món quà là cách giải quyết. Nhu cầu bên dưới là được quan tâm, thấy mình quan trọng."),
            .line("birthday.5", 0, .giraffe, .need,
                  "Oui. J'ai besoin de sentir que je compte pour toi.",
                  "Ừ. Tớ cần cảm thấy mình quan trọng với cậu.",
                  why: "Nhu cầu, không đòi một việc cụ thể. Panda có thể tự tìm cách đáp lại."),
            .rewrite("birthday.6", 0,
                     "Tu as intérêt à te rattraper.",
                     "Cậu liệu mà chuộc lỗi đi.",
                     why: "Một lời mời cụ thể: ngày, việc. « Tu sais ce que tu as à faire » bắt Panda đoán, và đoán sai thì lại bị trách.",
                     [
                        jackal("Tu sais ce que tu as à faire.",
                             "Cậu biết mình phải làm gì rồi đấy."),
                        jackal("Montre-moi que je compte pour toi.",
                             "Chứng minh là tớ quan trọng với cậu đi."),
                        giraffe("Est-ce que tu voudrais dîner avec moi samedi pour le fêter ?",
                                "Thứ Bảy cậu đi ăn tối với tớ để mừng sinh nhật nhé?"),
                     ]),
        ]
    )

    static let beach = Story(
        id: "beach", intent: .worry, title: "À la plage", gloss: "Ở bãi biển", scene: "honu-lagoon",
        cast: [Animal(emoji: "🦭", name: "Phoque", gloss: "Hải cẩu", drawing: "seal"), Animal(emoji: "🐧", name: "Pingouin", gloss: "Chim cánh cụt", drawing: "penguin")],
        beats: [
            .narration("beach.0",
                       "Pingouin nage loin du bord. Son père, Phoque, ne le voit plus pendant une minute. Quand Pingouin revient, Phoque l'attend.",
                       "Chim cánh cụt bơi xa bờ. Bố nó, Hải cẩu, mất dấu con suốt một phút. Khi con quay vào, bố đang đợi."),
            .line("beach.1", 0, .jackal, .observation,
                  "Tu es complètement inconscient !",
                  "Con đúng là chẳng biết nghĩ gì cả!",
                  why: "Một nhãn dán lên đứa trẻ. Nó nghe thấy mình bị chê, chứ không hiểu vì sao bố sợ."),
            .line("beach.2", 0, .giraffe, .observation,
                  "Tu as nagé jusqu'aux bouées, et je ne te voyais plus.",
                  "Con bơi ra tận chỗ phao, và bố không nhìn thấy con nữa.",
                  why: "Chuyện vừa xảy ra, kể lại đúng như vậy."),
            .line("beach.3", 0, .giraffe, .feeling,
                  "J'ai eu très peur.",
                  "Bố đã rất sợ.",
                  why: "Một cảm xúc thật, ngắn gọn. Trẻ con hiểu ngay."),
            .line("beach.4", 1, .jackal, .feeling,
                  "Tu me prends pour un bébé !",
                  "Bố coi con như em bé ấy!",
                  why: "Trẻ con cũng nói kiểu chó rừng. « Tu me prends pour… » là đoán ý bố. Cảm xúc thật có thể là bực, xấu hổ, muốn được tự do."),
            .line("beach.5", 0, .giraffe, .need,
                  "J'ai besoin de savoir que tu es en sécurité.",
                  "Bố cần biết con được an toàn.",
                  why: "An toàn là nhu cầu, và câu này không cấm con điều gì."),
            .rewrite("beach.6", 0,
                     "Tu ne te baignes plus de la journée.",
                     "Hôm nay con không được xuống nước nữa.",
                     why: "Một việc cụ thể con làm được, và con có thể trả lời. « Sois prudent » không nói phải làm gì; « on rentre » là lời doạ.",
                     [
                        jackal("Sois prudent.",
                             "Cẩn thận đấy."),
                        giraffe("Est-ce que tu veux bien rester là où tu as pied ?",
                                "Con có đồng ý chỉ bơi ở chỗ chân chạm đáy không?"),
                        jackal("Si tu recommences, on rentre.",
                             "Còn làm thế nữa là về nhà."),
                     ]),
        ]
    )

    static let hike = Story(
        id: "hike", intent: .reproach, title: "La randonnée", gloss: "Chuyến leo núi", scene: "vector-range",
        cast: [Animal(emoji: "🐘", name: "Éléphant", gloss: "Voi", drawing: "elephant"), Animal(emoji: "🐐", name: "Chèvre", gloss: "Dê", drawing: "goat")],
        beats: [
            .narration("hike.0",
                       "Chèvre grimpe vite. Éléphant est loin derrière, et il a mal aux pieds. Au sommet, il la rejoint enfin.",
                       "Dê leo nhanh. Voi ở tít phía sau, chân đau. Lên tới đỉnh, Voi mới đuổi kịp."),
            .line("hike.1", 0, .jackal, .observation,
                  "Tu ne penses qu'à toi.",
                  "Cậu chỉ biết nghĩ cho mình.",
                  why: "Một phán xét về tính cách. Dê sẽ cãi, và quên mất đôi chân đau của Voi."),
            .line("hike.2", 0, .giraffe, .observation,
                  "Depuis une heure, tu marches devant et tu ne m'attends pas aux croisements.",
                  "Suốt một tiếng nay, cậu đi trước và không đợi tớ ở các ngã rẽ.",
                  why: "Thời gian và việc làm, không đoán ý."),
            .line("hike.3", 0, .jackal, .feeling,
                  "Je me sens rejeté.",
                  "Tớ thấy mình bị bỏ rơi.",
                  why: "« Rejeté » nói về điều Dê làm với mình. Cảm xúc thật: mệt, cô đơn."),
            .line("hike.4", 0, .giraffe, .feeling,
                  "Je suis fatigué, et je me sens un peu seul.",
                  "Tớ mệt, và thấy hơi cô đơn.",
                  why: "« Je me sens seul » là cảm xúc thật: nó nói về mình, không về Dê."),
            .line("hike.5", 0, .giraffe, .need,
                  "J'ai besoin de compagnie, et de pauses.",
                  "Tớ cần có bạn đi cùng, và được nghỉ chân.",
                  why: "Hai nhu cầu rõ ràng. Dê có nhiều cách để đáp ứng."),
            .rewrite("hike.6", 0,
                     "Arrête de courir comme une folle.",
                     "Đừng có chạy như điên thế nữa.",
                     why: "Một việc cụ thể, dễ làm. « Faire attention aux autres » quá mơ hồ; « continue sans moi » là trách móc trá hình.",
                     [
                        giraffe("Est-ce que tu pourrais m'attendre à chaque croisement ?",
                                "Cậu đợi tớ ở mỗi ngã rẽ được không?"),
                        jackal("Tu pourrais faire attention aux autres.",
                             "Cậu nên để ý đến người khác chứ."),
                        jackal("Continue sans moi, de toute façon tu t'en fiches.",
                             "Đi tiếp mà không cần tớ đi, đằng nào cậu cũng chẳng quan tâm."),
                     ]),
        ]
    )
}
