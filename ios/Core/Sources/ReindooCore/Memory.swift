import Foundation

/// Ce que l'utilisateur dit après avoir vu le sens : il le savait, ou pas.
/// Deux réponses suffisent. Quatre (« difficile », « facile ») ralentissent le
/// reel sans beaucoup changer le calendrier.
public enum Recall: String, Codable, Sendable, CaseIterable {
    case forgot
    case knew
}

/// Ce que l'app sait de la mémoire d'un mot, au sens de FSRS.
public struct Memory: Codable, Equatable, Sendable {
    /// En jours : le temps au bout duquel la chance de se souvenir tombe à 90 %.
    public var stability: Double
    /// De 1 (facile) à 10 (dur).
    public var difficulty: Double
    public var reviewedAt: Date
    /// Quand le mot doit revenir.
    public var due: Date
    public var reviews: Int
    public var lapses: Int

    /// La chance de se souvenir du mot à cet instant, de 0 à 1.
    public func retrievability(at date: Date) -> Double {
        FSRS.retrievability(elapsed: FSRS.days(from: reviewedAt, to: date), stability: stability)
    }
}

/// FSRS-5, l'algorithme d'Anki depuis 2023, avec ses poids par défaut.
/// L'espacement est l'effet le plus solide de la recherche sur la mémoire
/// (Cepeda et al. 2006) ; FSRS en tire un calendrier mot par mot.
/// Les formules suivent ts-fsrs, l'implémentation de référence.
enum FSRS {
    static let w: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
        1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
    ]
    static let decay = -0.5
    /// Choisi pour que la chance vaille 90 % quand le temps écoulé égale la stabilité.
    static let factor = 19.0 / 81.0
    /// La chance de se souvenir que le calendrier vise.
    static let retention = 0.9
    static let maximumDays = 36500.0
    static let day = 86_400.0

    static func days(from start: Date, to end: Date) -> Double {
        max(0, end.timeIntervalSince(start) / day)
    }

    static func retrievability(elapsed: Double, stability: Double) -> Double {
        pow(1 + factor * elapsed / stability, decay)
    }

    /// En jours entiers, un au moins : le reel rattrape le même jour ce qui
    /// vient d'être oublié, sans attendre le calendrier.
    static func interval(_ stability: Double) -> Double {
        let exact = stability / factor * (pow(retention, 1 / decay) - 1)
        return min(max(exact.rounded(), 1), maximumDays)
    }

    static func grade(_ recall: Recall) -> Double {
        switch recall {
        case .forgot: 1
        case .knew: 3
        }
    }

    static func initialDifficulty(_ grade: Double) -> Double {
        w[4] - exp(w[5] * (grade - 1)) + 1
    }

    static func clampDifficulty(_ value: Double) -> Double {
        min(max(value, 1), 10)
    }

    static func first(_ recall: Recall, at date: Date) -> Memory {
        let g = grade(recall)
        let stability = w[Int(g) - 1]
        return Memory(
            stability: stability, difficulty: clampDifficulty(initialDifficulty(g)),
            reviewedAt: date, due: date.addingTimeInterval(interval(stability) * day),
            reviews: 1, lapses: recall == .forgot ? 1 : 0
        )
    }

    static func next(_ memory: Memory, _ recall: Recall, at date: Date) -> Memory {
        let g = grade(recall)
        let elapsed = days(from: memory.reviewedAt, to: date)
        let s = memory.stability, d = memory.difficulty
        let r = retrievability(elapsed: elapsed, stability: s)

        let stability: Double
        if elapsed < 1 {
            // Deux fois le même jour : la mémoire à court terme compte, mais peu.
            stability = s * exp(w[17] * (g - 3 + w[18]))
        } else if recall == .knew {
            // Plus le mot était près d'être oublié, plus s'en souvenir le fixe.
            stability = s * (1 + exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1))
        } else {
            let lapse = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp(w[14] * (1 - r))
            stability = min(lapse, s)
        }

        // Le pas s'amortit près de 10, puis la difficulté revient doucement vers la moyenne.
        let step = -w[6] * (g - 3) * (10 - d) / 9
        let difficulty = clampDifficulty(w[7] * initialDifficulty(4) + (1 - w[7]) * (d + step))

        let kept = max(stability, 0.01)
        return Memory(
            stability: kept, difficulty: difficulty,
            reviewedAt: date, due: date.addingTimeInterval(interval(kept) * day),
            reviews: memory.reviews + 1, lapses: memory.lapses + (recall == .forgot ? 1 : 0)
        )
    }
}
