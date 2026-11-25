// Trois histoires qui ne se jouent pas entre deux animaux.
//
// « La petite voix » : le chacal parle aussi dans notre tête. On s'y juge
// comme on juge les autres, et la girafe s'y apprend de la même façon.
//
// « Le corps parle » : une émotion se sent avant d'avoir un nom, et le français
// la loge dans le corps — une boule dans la gorge, le cœur serré. Pour qui
// apprend la langue, ce sont justement les expressions qu'un dictionnaire
// explique mal. Le trou porte sur la partie du corps, article compris, et les
// leurres sont choisis pour ne former aucune expression courante : « le ventre
// serré » se dit aussi, il n'est donc pas proposé à côté du « cœur serré ».
//
// « Un besoin, deux chemins » : deux animaux veulent des choses différentes
// pour la même raison. On se dispute sur la stratégie ; le besoin, lui, est
// commun. C'est le pas qui ouvre une sortie au conflit.

private func right(_ text: String, _ gloss: String) -> Rewrite { Rewrite(text: text, gloss: gloss, isRight: true) }
private func wrong(_ text: String, _ gloss: String) -> Rewrite { Rewrite(text: text, gloss: gloss, isRight: false) }

extension Story {
    static let voice = Story(
        id: "voice", title: "La petite voix", gloss: "Tiếng nói bên trong", scene: "night-reef",
        cast: [Animal(emoji: "🐼", name: "Panda", gloss: "Gấu trúc"), Animal(emoji: "🐺", name: "Chacal", gloss: "Chó rừng")],
        beats: [
            .narration("voice.0",
                       "Panda a oublié la réunion de 10 heures. Ses collègues l'ont attendu. Dans sa tête, une petite voix se met à parler.",
                       "Gấu trúc quên mất cuộc họp lúc 10 giờ. Đồng nghiệp đã phải chờ. Trong đầu cậu, một tiếng nói nhỏ bắt đầu lên tiếng."),
            .line("voice.1", 1, .jackal, .observation,
                  "Tu es vraiment nul.",
                  "Mày đúng là đồ vô dụng.",
                  why: "Tự phán xét mình cũng là tiếng chó rừng. Một lần quên không biến ai thành « nul »."),
            .line("voice.2", 0, .giraffe, .observation,
                  "J'ai oublié la réunion de 10 heures.",
                  "Mình đã quên cuộc họp lúc 10 giờ.",
                  why: "Chỉ là sự việc. Nhìn thẳng vào nó mà không tự mắng."),
            .line("voice.3", 1, .jackal, .feeling,
                  "Tu devrais avoir honte.",
                  "Mày phải biết xấu hổ chứ.",
                  why: "« Tu devrais » là mệnh lệnh, không phải cảm xúc. Nó bắt mình cảm thấy điều gì đó thay vì hỏi mình đang cảm thấy gì."),
            .line("voice.4", 0, .giraffe, .feeling,
                  "Je suis déçu, et un peu inquiet.",
                  "Mình thất vọng, và hơi lo.",
                  why: "Cảm xúc thật, nói với chính mình một cách nhẹ nhàng."),
            .line("voice.5", 1, .jackal, .need,
                  "Il faut que tu sois parfait.",
                  "Mày phải hoàn hảo.",
                  why: "Hoàn hảo là một đòi hỏi không ai đáp ứng được, không phải nhu cầu. Nhu cầu bên dưới có thể là: được tin cậy, được tôn trọng."),
            .line("voice.6", 0, .giraffe, .need,
                  "J'ai besoin d'être fiable, parce que mes collègues comptent pour moi.",
                  "Mình cần là người đáng tin, vì đồng nghiệp quan trọng với mình.",
                  why: "Lời tự trách giấu một nhu cầu đẹp: mình buồn vì mình quý đồng nghiệp."),
            .rewrite("voice.7", 1,
                     "Tu rates toujours tout.",
                     "Mày lúc nào cũng hỏng việc.",
                     why: "Một lời đề nghị với chính mình: cụ thể, làm được ngay. « Plus jamais » là lời hứa không giữ nổi; « je suis comme ça » là buông xuôi.",
                     [
                        wrong("Je ne recommencerai plus jamais.", "Mình sẽ không bao giờ tái phạm nữa."),
                        right("La prochaine fois, je mets une alarme dans mon téléphone.", "Lần sau, mình sẽ đặt báo thức trong điện thoại."),
                        wrong("Je suis comme ça, je n'y peux rien.", "Mình là vậy, chẳng làm gì được."),
                     ]),
            .narration("voice.8",
                       "Panda écrit un mot d'excuse à ses collègues, puis règle une alarme. La petite voix se tait.",
                       "Gấu trúc viết lời xin lỗi gửi đồng nghiệp, rồi đặt báo thức. Tiếng nói nhỏ im bặt."),
        ]
    )

    static let body = Story(
        id: "body", title: "Le corps parle", gloss: "Cơ thể lên tiếng", scene: "koi-mosaic",
        cast: [Animal(emoji: "🦒", name: "Girafe", gloss: "Hươu"), Animal(emoji: "🐺", name: "Chacal", gloss: "Chó rừng")],
        beats: [
            .narration("body.0",
                       "Une émotion se sent dans le corps avant d'avoir un nom. Le français la place souvent quelque part : la gorge, le cœur, le ventre.",
                       "Cảm xúc hiện lên trong cơ thể trước khi ta gọi được tên. Tiếng Pháp hay đặt nó vào một chỗ: cổ họng, trái tim, bụng."),
            .body("body.1", "J'ai une boule dans ___.", "J'ai une boule dans la gorge.", "Tôi nghẹn ở cổ họng.",
                  feeling: "L'émotion retenue",
                  why: "Khi muốn khóc mà cố nén, cổ họng như có một cục nghẹn. Thường đi với buồn, xúc động.",
                  [right("la gorge", "cổ họng"), wrong("le dos", "lưng"), wrong("les jambes", "chân"), wrong("la peau", "da")]),
            .body("body.2", "J'ai ___ serré.", "J'ai le cœur serré.", "Tôi thắt lòng.",
                  feeling: "La tristesse",
                  why: "Trái tim như bị bóp lại: buồn, thương, hoặc lo cho ai đó.",
                  [right("le cœur", "trái tim"), wrong("le dos", "lưng"), wrong("le nez", "mũi"), wrong("le pied", "bàn chân")]),
            .body("body.3", "J'ai ___ noué.", "J'ai l'estomac noué.", "Tôi thắt ruột, bồn chồn.",
                  feeling: "L'angoisse",
                  why: "Dạ dày thắt lại trước một kỳ thi, một cuộc nói chuyện khó: đó là lo âu.",
                  [right("l'estomac", "dạ dày"), wrong("le dos", "lưng"), wrong("le nez", "mũi"), wrong("le pied", "bàn chân")]),
            .body("body.4", "J'ai des papillons dans ___.", "J'ai des papillons dans le ventre.", "Tôi thấy bươm bướm bay trong bụng.",
                  feeling: "L'excitation",
                  why: "Bồn chồn mà vui: trước buổi hẹn đầu tiên, trước một tin tốt.",
                  [right("le ventre", "bụng"), wrong("la gorge", "cổ họng"), wrong("les mains", "tay"), wrong("le dos", "lưng")]),
            .body("body.5", "J'en ai eu ___ coupées.", "J'en ai eu les jambes coupées.", "Tôi rụng rời cả chân tay.",
                  feeling: "Le choc",
                  why: "Một tin bất ngờ, hay mệt rã rời, đến mức chân không còn đứng vững.",
                  [right("les jambes", "chân"), wrong("les mains", "tay"), wrong("les oreilles", "tai"), wrong("les épaules", "vai")]),
            .body("body.6", "J'ai ___ en coton.", "J'ai les jambes en coton.", "Chân tôi mềm nhũn như bông.",
                  feeling: "La peur ou la fatigue",
                  why: "Chân mềm như bông khi sợ, khi run, hay khi kiệt sức.",
                  [right("les jambes", "chân"), wrong("les mains", "tay"), wrong("les oreilles", "tai"), wrong("les épaules", "vai")]),
            .body("body.7", "J'en ai plein ___.", "J'en ai plein le dos.", "Tôi ngán đến tận cổ.",
                  feeling: "Le ras-le-bol",
                  why: "Như vác một gánh nặng trên lưng quá lâu: chán ngấy, hết chịu nổi.",
                  [right("le dos", "lưng"), wrong("le cœur", "trái tim"), wrong("la gorge", "cổ họng"), wrong("le ventre", "bụng")]),
            .body("body.8", "J'en ai gros sur ___.", "J'en ai gros sur le cœur.", "Tôi nặng trĩu trong lòng.",
                  feeling: "Le chagrin",
                  why: "Nỗi buồn hay ấm ức dồn lại, chưa nói ra được.",
                  [right("le cœur", "trái tim"), wrong("le dos", "lưng"), wrong("la tête", "đầu"), wrong("le ventre", "bụng")]),
            .body("body.9", "J'ai la chair de ___.", "J'ai la chair de poule.", "Tôi nổi da gà.",
                  feeling: "La peur ou l'émotion forte",
                  why: "Da gà nổi lên khi sợ, khi lạnh, hay khi một bài hát chạm vào lòng. Tiếng Pháp nói « da gà mái », tiếng Việt nói « da gà ».",
                  [right("poule", "gà mái"), wrong("lapin", "thỏ"), wrong("canard", "vịt"), wrong("vache", "bò cái")]),
            .body("body.10", "J'ai les nerfs à fleur de ___.", "J'ai les nerfs à fleur de peau.", "Tôi dễ nổi cáu, thần kinh căng như dây đàn.",
                  feeling: "L'irritabilité",
                  why: "Thần kinh nằm ngay dưới da: chạm nhẹ là phản ứng. Mệt và căng thẳng thì dễ thế.",
                  [right("peau", "da"), wrong("cœur", "tim"), wrong("tête", "đầu"), wrong("gorge", "cổ họng")]),
            .body("body.11", "J'ai rougi jusqu'aux ___.", "J'ai rougi jusqu'aux oreilles.", "Tôi đỏ mặt tía tai.",
                  feeling: "La gêne",
                  why: "Ngượng đến mức đỏ tận mang tai. Tiếng Việt cũng có « tía tai »!",
                  [right("oreilles", "tai"), wrong("pieds", "bàn chân"), wrong("épaules", "vai"), wrong("genoux", "đầu gối")]),
            .body("body.12", "J'ai ___ moites.", "J'ai les mains moites.", "Tay tôi rịn mồ hôi.",
                  feeling: "Le stress",
                  why: "Bàn tay ướt mồ hôi trước khi lên nói, trước một cuộc phỏng vấn.",
                  [right("les mains", "tay"), wrong("les oreilles", "tai"), wrong("les épaules", "vai"), wrong("les genoux", "đầu gối")]),
        ]
    )

    static let needs = Story(
        id: "needs", title: "Un besoin, deux chemins", gloss: "Một nhu cầu, hai cách", scene: "paper-garden",
        cast: [Animal(emoji: "🐻", name: "Ours", gloss: "Gấu"), Animal(emoji: "🦔", name: "Hérisson", gloss: "Nhím")],
        beats: [
            .narration("needs.0",
                       "Un besoin est le même pour tout le monde. Une stratégie est une façon, parmi d'autres, d'y répondre. On se dispute souvent sur la stratégie, alors qu'on partage le besoin.",
                       "Nhu cầu thì ai cũng giống nhau. Chiến lược chỉ là một trong nhiều cách đáp ứng nó. Người ta hay cãi nhau về cách làm, trong khi lại có chung một nhu cầu."),
            .need("needs.1",
                  "Allons au cinéma ce soir !", "Tối nay mình đi xem phim đi!",
                  "Je préfère rester à la maison, sous la couette.", "Tớ thích ở nhà, cuộn trong chăn hơn.",
                  why: "Rạp phim hay chăn ấm đều là cách để thư giãn sau một tuần mệt. Thấy chung nhu cầu rồi, hai bạn có thể tìm cách thứ ba: xem phim ở nhà.",
                  [right("de la détente", "được thư giãn"), wrong("de l'ordre", "sự ngăn nắp"), wrong("de la reconnaissance", "được ghi nhận"), wrong("de la justice", "sự công bằng")]),
            .need("needs.2",
                  "Je voudrais qu'on dîne ensemble tous les soirs.", "Tớ muốn tối nào mình cũng ăn cơm cùng nhau.",
                  "Moi, j'aimerais qu'on s'appelle à midi.", "Còn tớ thì muốn trưa mình gọi điện cho nhau.",
                  why: "Ăn tối cùng nhau hay gọi điện buổi trưa: cả hai đều muốn gần gũi.",
                  [wrong("de l'autonomie", "sự tự chủ"), right("du lien", "sự gắn kết"), wrong("du repos", "nghỉ ngơi"), wrong("de l'efficacité", "hiệu quả")]),
            .need("needs.3",
                  "Écrivons tout le plan avant de commencer.", "Mình viết xong cả kế hoạch rồi hẵng bắt đầu.",
                  "Faisons un premier essai tout de suite.", "Mình làm thử ngay một lần đi.",
                  why: "Một bên lên kế hoạch, một bên thử luôn: cả hai đều muốn không phí công sức.",
                  [wrong("de la tendresse", "sự âu yếm"), wrong("du jeu", "được vui chơi"), right("de l'efficacité", "hiệu quả"), wrong("de la beauté", "cái đẹp")]),
            .need("needs.4",
                  "Dis-moi à quelle heure tu rentres ce soir.", "Cho tớ biết tối nay mấy giờ cậu về nhé.",
                  "Je t'envoie un message en partant de chez Léa, d'accord ?", "Tớ nhắn cho cậu lúc rời nhà Léa, được không?",
                  why: "Biết trước giờ về hay nhận một tin nhắn: cả hai cách đều để Gấu yên tâm.",
                  [right("de la tranquillité", "sự yên tâm"), wrong("de la compétition", "sự cạnh tranh"), wrong("du silence", "sự yên tĩnh"), wrong("de l'aventure", "phiêu lưu")]),
            .need("needs.5",
                  "Arrêtons-nous pour manger quelque chose.", "Mình dừng lại ăn chút gì đi.",
                  "Asseyons-nous un peu au soleil.", "Mình ngồi nghỉ một lát dưới nắng đi.",
                  why: "Ăn chút gì hay ngồi phơi nắng: cả hai đều muốn lấy lại sức.",
                  [wrong("de l'aventure", "phiêu lưu"), wrong("de l'ordre", "sự ngăn nắp"), wrong("de la justice", "sự công bằng"), right("du repos", "nghỉ ngơi")]),
            .narration("needs.6",
                       "Ours et Hérisson rient : ils voulaient la même chose depuis le début.",
                       "Gấu và Nhím bật cười: hoá ra từ đầu hai bạn đã muốn cùng một điều."),
        ]
    )
}
