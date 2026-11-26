// Trois histoires pour les intentions que les premières ne couvraient pas,
// prises dans l'ordre des chapitres de la *Communication progressive* :
// refuser (« Demander, accepter, refuser »), recevoir une critique (« Évaluer
// un travail »), entendre un sous-entendu (« Allusions et sous-entendus »).
// Les situations sont des actes de parole ; les répliques sont écrites ici.
//
// « Ce qui n'est pas dit » ne fait rien trier. On y écoute une remarque à
// double sens et l'on cherche ce que l'autre voudrait au fond. Reconnaître
// pèse moins que produire : c'est une porte d'entrée douce.

private func right(_ text: String, _ gloss: String) -> Rewrite { Rewrite(text: text, gloss: gloss, isRight: true) }
private func wrong(_ text: String, _ gloss: String) -> Rewrite { Rewrite(text: text, gloss: gloss, isRight: false) }

extension Story {
    static let move = Story(
        id: "move", intent: .refuse, title: "Le déménagement", gloss: "Chuyển nhà", scene: "blueprint",
        cast: [Animal(emoji: "🐨", name: "Koala", gloss: "Gấu túi", drawing: "koala"), Animal(emoji: "🐧", name: "Pingouin", gloss: "Chim cánh cụt", drawing: "penguin")],
        beats: [
            .narration("move.0",
                       "Pingouin déménage samedi et demande à Koala de venir porter des cartons. Koala a travaillé tous les week-ends du mois. Il rêve d'un samedi au calme.",
                       "Chim cánh cụt chuyển nhà vào thứ Bảy và nhờ Gấu túi đến khuân thùng giúp. Gấu túi đã đi làm suốt các cuối tuần trong tháng. Cậu chỉ mong một ngày thứ Bảy yên tĩnh."),
            .line("move.1", 0, .jackal, .request,
                  "Bon… d'accord. De toute façon, c'est toujours moi qui m'y colle.",
                  "Thôi… được rồi. Đằng nào lúc nào cũng là tớ phải làm.",
                  why: "Miệng nói « oui » mà lòng nói « non »: cái « oui » này đầy trách móc. Pingouin sẽ có một người giúp đang bực, và cả hai cùng khó chịu."),
            .line("move.2", 0, .giraffe, .observation,
                  "J'ai travaillé les quatre derniers week-ends.",
                  "Tớ đã đi làm bốn cuối tuần vừa rồi.",
                  why: "Một sự việc, không phải lời bào chữa. Pingouin hiểu ngay vì sao Gấu túi mệt."),
            .line("move.3", 0, .jackal, .observation,
                  "Tu aurais pu me demander plus tôt, franchement !",
                  "Cậu phải hỏi tớ sớm hơn chứ!",
                  why: "Từ chối bằng cách trách người kia. Pingouin chỉ nghe thấy mình có lỗi, không nghe thấy Gấu túi cần gì."),
            .line("move.4", 0, .giraffe, .feeling,
                  "Je suis vraiment épuisé, et j'ai peur de craquer si je ne m'arrête pas.",
                  "Tớ thật sự kiệt sức, và tớ sợ mình sẽ gục nếu không nghỉ.",
                  why: "Cảm xúc thật, ở ngôi thứ nhất. Nói được « non » mà không cần tìm cớ."),
            .line("move.5", 0, .jackal, .need,
                  "Je ne peux pas, j'ai un truc.",
                  "Tớ không đi được, tớ có việc.",
                  why: "Một cái cớ mơ hồ che đi nhu cầu thật. Pingouin không biết có nên hỏi lại lúc khác không, và Gấu túi cũng không được hiểu."),
            .line("move.6", 0, .giraffe, .need,
                  "J'ai besoin d'un samedi de repos, sans rien prévoir.",
                  "Tớ cần một ngày thứ Bảy nghỉ ngơi, không lên kế hoạch gì cả.",
                  why: "Nhu cầu nghỉ ngơi, nói thẳng. Nói « non » với việc khuân thùng là nói « oui » với chính mình."),
            .line("move.7", 0, .giraffe, .feeling,
                  "Tu as peur de ne pas t'en sortir tout seul samedi ?",
                  "Cậu sợ thứ Bảy một mình làm không xuể à?",
                  why: "Từ chối mà vẫn lắng nghe: Gấu túi đoán điều Pingouin lo, để cậu ấy không thấy mình bị bỏ rơi."),
            .rewrite("move.8", 0,
                     "Non. Débrouille-toi.",
                     "Không. Tự lo đi.",
                     why: "Một lời « non » kiểu hươu đi kèm một lời « oui » khác: Gấu túi nói rõ mình làm được gì, rồi để Pingouin quyết. « On verra » bắt người kia chờ mà chẳng biết gì.",
                     [
                        wrong("Peut-être, on verra samedi matin.", "Có lẽ, sáng thứ Bảy rồi tính."),
                        right("Samedi, je ne viendrai pas. Mais dimanche soir, je peux t'aider à monter les meubles. Ça t'irait ?",
                              "Thứ Bảy tớ không đến đâu. Nhưng tối Chủ nhật tớ có thể giúp cậu lắp đồ. Cậu thấy được không?"),
                        wrong("Désolé, je suis vraiment un ami nul.", "Xin lỗi, tớ đúng là một người bạn tồi."),
                     ]),
            .narration("move.9",
                       "Pingouin sourit : « Dimanche, c'est parfait. Les meubles, c'est le plus dur. »",
                       "Chim cánh cụt mỉm cười: « Chủ nhật thì tuyệt. Lắp đồ mới là khó nhất. »"),
        ]
    )

    static let feedback = Story(
        id: "feedback", intent: .criticism, title: "La remarque", gloss: "Lời nhận xét", scene: "halftone-dawn",
        cast: [Animal(emoji: "🦭", name: "Phoque", gloss: "Hải cẩu", drawing: "seal"), Animal(emoji: "🦉", name: "Chouette", gloss: "Cú", drawing: "owl")],
        beats: [
            .narration("feedback.0",
                       "Phoque a rendu son rapport hier. Ce matin, Chouette, sa responsable, lui dit : « Il y a beaucoup de fautes, et il manque la conclusion. »",
                       "Hải cẩu nộp báo cáo hôm qua. Sáng nay Cú, trưởng nhóm của cậu, nói: « Có nhiều lỗi, và còn thiếu phần kết luận. »"),
            .line("feedback.1", 0, .jackal, .observation,
                  "Je suis vraiment incapable.",
                  "Mình đúng là vô dụng.",
                  why: "Nghe lời chê rồi tự kết án mình: chó rừng hướng vào trong. Một bản báo cáo có lỗi không biến ai thành « incapable »."),
            .line("feedback.2", 0, .giraffe, .observation,
                  "Vous avez relevé des fautes, et la conclusion manque.",
                  "Chị đã chỉ ra các lỗi, và phần kết luận còn thiếu.",
                  why: "Nhắc lại đúng điều đã nghe, không thêm « chị chê em ». Lời nhận xét nói về bản báo cáo, không nói về con người."),
            .line("feedback.3", 0, .jackal, .feeling,
                  "Vous ne voyez jamais que ce qui ne va pas.",
                  "Chị lúc nào cũng chỉ thấy cái dở.",
                  why: "Phản đòn: lời chê thành lời buộc tội Cú. Hai người sẽ cãi nhau về tính cách, không ai nói về bản báo cáo nữa."),
            .line("feedback.4", 0, .giraffe, .feeling,
                  "Je suis déçu : j'y ai passé beaucoup de temps.",
                  "Em thất vọng: em đã bỏ nhiều thời gian vào nó.",
                  why: "Hươu lắng nghe chính mình trước: thất vọng, vì mình mong công sức được thấy. Nhận ra điều đó, lời chê bớt nhói."),
            .line("feedback.5", 0, .jackal, .need,
                  "Il faut que vous me disiez toujours bravo d'abord.",
                  "Chị phải luôn khen em trước đã.",
                  why: "Một đòi hỏi, không phải nhu cầu. Nhu cầu bên dưới là được ghi nhận, và có nhiều cách để đáp ứng nó."),
            .line("feedback.6", 0, .giraffe, .need,
                  "Vous avez besoin que le rapport soit prêt pour le client ?",
                  "Chị cần bản báo cáo sẵn sàng để gửi khách hàng phải không?",
                  why: "Hươu lắng nghe người kia: đằng sau lời chê là một nhu cầu, ở đây là chất lượng và sự yên tâm trước khách hàng."),
            .rewrite("feedback.7", 0,
                     "Bon, je refais tout, puisque rien ne va.",
                     "Thôi, em làm lại hết, vì chẳng có gì ổn cả.",
                     why: "Một lời đề nghị cụ thể: hỏi rõ điều cần sửa và hẹn một thời điểm. « Je refais tout » là dỗi; « c'est votre avis » là đóng cửa.",
                     [
                        wrong("C'est votre avis, mais moi je le trouve bien.", "Đó là ý của chị, chứ em thấy nó ổn."),
                        wrong("Je ne suis pas fait pour ce travail.", "Em không hợp với công việc này."),
                        right("Vous pourriez me montrer les trois fautes les plus gênantes ? Je vous renvoie la version corrigée demain midi.",
                              "Chị chỉ giúp em ba lỗi đáng ngại nhất được không? Trưa mai em gửi lại bản đã sửa."),
                     ]),
            .narration("feedback.8",
                       "Chouette entoure trois phrases. « Le reste est clair. Et ton plan est bon, je ne te l'ai pas assez dit. »",
                       "Cú khoanh ba câu. « Phần còn lại rõ ràng. Và dàn ý của em tốt, chị chưa nói với em điều đó đủ. »"),
        ]
    )

    static let hints = Story(
        id: "hints", intent: .hint, title: "Ce qui n'est pas dit", gloss: "Điều không nói ra", scene: "night-reef",
        cast: [
            Animal(emoji: "🐱", name: "Chatte", gloss: "Mèo", drawing: "cat"),
            Animal(emoji: "🦊", name: "Renard", gloss: "Cáo", drawing: "fox"),
            Animal(emoji: "🐐", name: "Chèvre", gloss: "Dê", drawing: "goat"),
            Animal(emoji: "🐰", name: "Lapine", gloss: "Thỏ", drawing: "rabbit"),
        ],
        beats: [
            .narration("hints.0",
                       "On ne dit pas toujours ce qu'on veut. Souvent, on le laisse entendre : une remarque, une petite pique. Le chacal y entend une attaque. La girafe y entend un besoin.",
                       "Không phải lúc nào người ta cũng nói thẳng điều mình muốn. Họ hay nói bóng gió: một lời nhận xét, một câu châm chọc. Chó rừng nghe thấy sự tấn công. Hươu nghe thấy một nhu cầu."),
            .hint("hints.1", 0,
                  "Ah, tu es là, toi. On ne te voit plus.",
                  "À, cậu đấy à. Dạo này chẳng thấy mặt cậu đâu.",
                  why: "Đằng sau câu bóng gió là nỗi nhớ: Mèo cần được gắn kết. Hươu đoán nhu cầu và hỏi lại, thay vì tự vệ.",
                  [
                     wrong("Moi aussi, j'ai une vie, tu sais.", "Tớ cũng có cuộc sống riêng chứ."),
                     right("Je t'ai manqué ? Tu aimerais qu'on se voie plus souvent ?", "Cậu nhớ tớ à? Cậu muốn mình gặp nhau thường hơn?"),
                     wrong("Tu me reproches d'être venu ?", "Cậu trách tớ vì đã đến à?"),
                  ]),
            .hint("hints.2", 1,
                  "Ce n'est pas grave, je finirai tout seul, comme d'habitude.",
                  "Không sao, tớ sẽ tự làm xong một mình, như mọi khi.",
                  why: "« Comme d'habitude » là một lời trách nhẹ. Bên dưới là sự mệt mỏi, và nhu cầu được chia sẻ công việc.",
                  [
                     right("Tu es fatigué de tout porter seul ? Tu aimerais de l'aide ?", "Cậu mệt vì phải gánh một mình à? Cậu muốn được giúp không?"),
                     wrong("Personne ne t'a demandé de jouer les héros.", "Có ai bắt cậu làm anh hùng đâu."),
                     wrong("Très bien, alors fais-le.", "Được thôi, thế thì cứ làm đi."),
                  ]),
            .hint("hints.3", 2,
                  "Tiens, tu as encore acheté un nouveau téléphone ?",
                  "Ồ, cậu lại mua điện thoại mới à?",
                  why: "Chữ « encore » mang theo nỗi lo. Hai bạn chung tiền nhà, nên nhu cầu có thể là sự an tâm, sự minh bạch. Đoán rồi hỏi lại thì không phải bào chữa.",
                  [
                     wrong("C'est mon argent, je fais ce que je veux.", "Tiền của tớ, tớ thích làm gì thì làm."),
                     wrong("Tu es jalouse ?", "Cậu ghen tị à?"),
                     right("Tu es inquiète pour notre budget ? Tu voudrais qu'on en parle ?", "Cậu lo cho chi tiêu chung à? Cậu muốn mình nói chuyện về nó không?"),
                  ]),
            .hint("hints.4", 3,
                  "Bien sûr, toi, tu as toujours le temps de sortir.",
                  "Tất nhiên rồi, cậu thì lúc nào cũng có thời gian đi chơi.",
                  why: "Câu mỉa mai thường giấu một sự mệt mỏi: Thỏ cũng cần được nghỉ. Hươu nghe ra nhu cầu đó.",
                  [
                     right("Tu es débordée en ce moment ? Tu aurais besoin de souffler, toi aussi ?", "Dạo này cậu ngập việc à? Cậu cũng cần được thở một chút?"),
                     wrong("Organise-toi mieux, alors.", "Thế thì sắp xếp thời gian tốt hơn đi."),
                     wrong("Je ne vois pas où est le problème.", "Tớ không thấy có vấn đề gì cả."),
                  ]),
            .hint("hints.5", 0,
                  "Fais comme tu veux. De toute façon, mon avis ne compte pas.",
                  "Cậu cứ làm gì thì làm. Đằng nào ý kiến của tớ cũng chẳng quan trọng.",
                  why: "Buông xuôi trong lời nói thường là một lời kêu: Mèo cần được tham gia, được lắng nghe.",
                  [
                     wrong("Arrête de faire la victime.", "Thôi đừng đóng vai nạn nhân nữa."),
                     right("Tu es triste parce que tu voudrais qu'on décide ensemble ?", "Cậu buồn vì muốn mình cùng quyết định à?"),
                     wrong("D'accord, alors c'est moi qui décide.", "Được, vậy tớ quyết."),
                  ]),
            .narration("hints.6",
                       "La girafe ne devine pas toujours juste. Mais en posant la question, elle montre qu'elle écoute, et l'autre peut la corriger.",
                       "Hươu không phải lúc nào cũng đoán đúng. Nhưng khi hỏi lại, nó cho thấy mình đang lắng nghe, và người kia có thể sửa lại."),
        ]
    )
}
