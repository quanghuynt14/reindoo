// Les histoires se rangent par intention, comme les chapitres de la
// *Communication progressive du français* : « Demander, accepter, refuser »,
// « Gérer les conflits », « Allusions et sous-entendus ». Du livre on ne prend
// que cet ordre, des actes de parole ; aucune réplique n'en sort.
//
// Ranger par intention répond à la question qu'on se pose en ouvrant l'onglet :
// « quand m'en servir ? ». On ne vient pas faire une leçon ; on vient parce
// qu'on doit dire non à quelqu'un ce soir.

/// Ce qu'on cherche à faire avec ses mots.
public enum Intent: String, Codable, Sendable, CaseIterable {
    case feel
    case reproach
    case worry
    case refuse
    case criticism
    case repair
    case hint
    case agree
}

/// Une forme du français qui fait parler girafe. La girafe n'est pas seulement
/// plus douce : elle a sa grammaire. Le conditionnel laisse à l'autre le droit
/// de dire non, « j'ai besoin de » + nom n'oblige personne, la question devine
/// au lieu d'accuser. Montrer la forme ôte au jugement son poids moral : on
/// apprend du français, pas une bonne conduite.
///
/// Les formes se trouvent dans les phrases girafe elles-mêmes, par leurs
/// mots : une nouvelle histoire n'a rien à déclarer.
public struct GiraffeForm: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// La forme, en français.
    public var phrase: String
    /// Pourquoi elle fait girafe, en vietnamien comme les explications.
    public var note: String
    /// Le mot à ouvrir dans le dictionnaire.
    public var word: String
    /// Ce qui la trahit dans une phrase, en minuscules.
    var cues: [String]

    static func found(in text: String) -> [GiraffeForm] {
        let lower = text.lowercased().replacingOccurrences(of: "’", with: "'")
        return all.filter { form in form.cues.contains { lower.contains($0) } }
    }

    public static let all: [GiraffeForm] = [
        GiraffeForm(
            id: "facts", phrase: "depuis vingt minutes, depuis lundi",
            note: "Một mốc thời gian, một con số: lời quan sát mà camera cũng ghi lại được. « Toujours », « jamais » là phán xét.",
            word: "depuis", cues: ["depuis ", "derniers week-ends", "la troisième fois"]
        ),
        GiraffeForm(
            id: "feeling", phrase: "je suis + adjectif : agacé, déçu, inquiet",
            note: "Cảm xúc là một tính từ nói về mình. Tránh « je me sens + phân từ » như trahi, méprisé, abandonné: đó là đoán điều người khác đã làm.",
            word: "sentiment", cues: ["je suis agacé", "je suis déçu", "je suis découragée", "je suis inquiète", "je suis inquiet", "je suis énervé", "je suis vraiment épuisé", "j'ai eu peur", "je me sens seul", "je suis triste", "je suis fatigué"]
        ),
        GiraffeForm(
            id: "soft", phrase: "un peu, vraiment",
            note: "Những từ nhỏ giúp nói đúng mức cảm xúc, không phóng đại cũng không giấu đi.",
            word: "peu", cues: ["un peu triste", "un peu inquiet", "et un peu", "vraiment épuisé"]
        ),
        GiraffeForm(
            id: "need", phrase: "j'ai besoin de + nom",
            note: "Nói nhu cầu bằng một danh từ: repos, ordre, lien. Không ai bị bắt phải làm gì. « J'ai besoin que tu… » thường là một yêu cầu trá hình.",
            word: "besoin", cues: ["j'ai besoin d", "besoin de sommeil", "besoin de calme"]
        ),
        GiraffeForm(
            id: "wish", phrase: "j'aimerais, j'aurais aimé",
            note: "Nói điều mình mong, thay vì điều người kia đã làm sai. « J'aurais aimé être prévenu » nhẹ hơn nhiều so với « tu aurais pu me prévenir ! ».",
            word: "aimer", cues: ["j'aimerais", "j'aurais aimé", "ça me ferait plaisir"]
        ),
        GiraffeForm(
            id: "conditional", phrase: "tu serais d'accord pour… ? vous pourriez… ?",
            note: "Thì điều kiện làm lời đề nghị mềm lại và để người kia quyền nói « non ». Một yêu cầu không có chỗ cho « non » là một đòi hỏi.",
            word: "pouvoir", cues: ["serais d'accord", "seriez d'accord", "pourriez", "pourrais", "ça t'irait", "ça vous irait"]
        ),
        GiraffeForm(
            id: "question", phrase: "tu peux… ? est-ce que tu… ?",
            note: "Một câu hỏi, không phải mệnh lệnh: người kia có thể trả lời, có thể chọn. « Sois à l'heure » ra lệnh; « tu peux m'envoyer un message ? » đề nghị.",
            word: "demander", cues: ["tu peux ", "vous pouvez ", "est-ce que tu", "est-ce que vous", "on peut "]
        ),
        GiraffeForm(
            id: "guess", phrase: "tu es… parce que… ? tu aimerais… ?",
            note: "Hươu đoán cảm xúc và nhu cầu của người kia rồi hỏi lại. Đoán sai cũng không sao: người kia sẽ sửa, và thấy mình được lắng nghe.",
            word: "deviner", cues: ["parce que tu", "tu aimerais", "tu voudrais", "tu as peur", "vous avez besoin", "tu es fatigué", "tu es débordée", "tu es inquiète", "tu aurais besoin", "je t'ai manqué", "tu es triste", "tu avais peur"]
        ),
        GiraffeForm(
            id: "no-but", phrase: "je ne viendrai pas, mais je peux…",
            note: "Một lời « non » kiểu hươu đi kèm một lời « oui » khác: điều mình làm được. Người kia không bị bỏ lại tay trắng.",
            word: "mais", cues: ["mais je peux", "mais dimanche"]
        ),
    ]
}
