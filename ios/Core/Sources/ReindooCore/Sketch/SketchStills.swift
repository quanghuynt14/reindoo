/// Un dessin tel que l'app le montre : quel dessin, et à quelle place.
/// Chaque place a sa taille fixe. Ainsi tous les dessins se peignent une
/// fois, à la construction de l'app, et le téléphone ne fait que les afficher :
/// un écran qui s'ouvre a déjà son dessin, sans attendre ni clignoter.
public struct Still: Hashable, Sendable {
    public enum Use: String, Sendable {
        /// Une tête, dans une pastille ronde.
        case head
        /// Une scène entière, posée dans un cadre.
        case scene
        /// Un décor plein écran, derrière une histoire.
        case backdrop
        /// La bande d'un décor, derrière une ligne de la liste.
        case band
    }

    public let sketch: Sketch
    public let use: Use

    public static func head(_ sketch: Sketch) -> Still { Still(sketch: sketch, use: .head) }
    public static func scene(_ sketch: Sketch) -> Still { Still(sketch: sketch, use: .scene) }
    public static func backdrop(_ motif: Motif) -> Still { Still(sketch: .backdrop(motif), use: .backdrop) }
    public static func band(_ motif: Motif) -> Still { Still(sketch: .backdrop(motif), use: .band) }

    /// Le dessin déborde de son cadre et se rogne, au lieu de s'y loger.
    public var fills: Bool { use == .backdrop || use == .band }

    /// En pixels. Une tête s'affiche jusqu'à 80 points sur un écran 3× ; un
    /// décor de pastel flou se contente de 1,25 pixel par point sur le plus
    /// grand iPhone, une bande de 1,5 pour une ligne de 370 × 100 points.
    public var size: (width: Int, height: Int) {
        switch use {
        case .head: (240, 240)
        case .scene: (960, 400)
        case .backdrop: (550, 1196)
        case .band: (556, 150)
        }
    }

    public func plan() -> SketchPlan {
        sketch.plan(width: size.width, height: size.height, head: use == .head || use == .band)
    }

    /// Le nom du fichier peint, sans extension.
    public var name: String {
        let what = switch sketch {
        case .giraffe(let mood): "giraffe-\(mood.rawValue)"
        case .jackal(let mood): "jackal-\(mood.rawValue)"
        case .together: "together"
        case .animal(let species, let mood): "\(species.rawValue)-\(mood.rawValue)"
        case .backdrop(let motif): motif.rawValue
        case .glyph(let glyph): "glyph-\(glyph.rawValue)"
        }
        return "sketch-\(use.rawValue)-\(what)"
    }

    /// Tout ce que l'onglet Giao tiếp peut montrer. Les signes restent à part :
    /// petits et teintés par le texte, ils se tracent sur place.
    public static var all: [Still] {
        Sketch.GiraffeMood.allCases.map { head(.giraffe($0)) }
            + Sketch.JackalMood.allCases.map { head(.jackal($0)) }
            + Species.allCases.flatMap { species in Sketch.AnimalMood.allCases.map { head(.animal(species, $0)) } }
            + [scene(.together)]
            + Motif.allCases.flatMap { [backdrop($0), band($0)] }
    }
}
