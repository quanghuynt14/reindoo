import Foundation

/// Un thème du reel : un décor animé et le voile posé dessus pour que le mot
/// se lise. D'après les vingt scènes de theme-examples (Anthropic, Apache 2.0),
/// recomposées pour un téléphone tenu droit.
public struct SceneTheme: Sendable, Identifiable, Equatable {
    public enum Window: String, Sendable, Codable { case light, dark }

    /// Le voile : sa teinte, son flou et son opacité.
    public struct Glass: Sendable, Equatable {
        public var blur: Double
        public var tint: RGBA
        public var opacity: Double
    }

    public var id: String
    public var title: String
    /// Le décor est fait pour un fond clair ou sombre : le texte s'y accorde.
    public var window: Window
    /// Le même décor pour l'autre sorte de fond.
    public var twin: String?
    public var glass: Glass

    public static func == (left: SceneTheme, right: SceneTheme) -> Bool { left.id == right.id }

    /// Combien d'images par seconde le décor demande. Ceux qui avancent par
    /// marches (`steps()`) n'ont pas besoin de plus : la batterie dit merci.
    public var frameRate: Double {
        switch id {
        case "teletext-clouds": 4
        case "dither-dunes", "dither-dunes-night", "halftone-dawn", "halftone-dusk": 8
        case "departure-board", "braille-stars": 10
        default: 30
        }
    }

    /// Les décors ont été dessinés pour un écran d'ordinateur, où une unité
    /// vaut à peu près un pixel. Sur un téléphone, une unité vaut moins d'un
    /// point : les cellules d'ASCII restent fines, les glyphes nets.
    public static let unitsPerPoint = 1.35

    /// Certains décors ont des sujets trop grands pour un téléphone : on les
    /// dessine plus serrés.
    static let densities: [String: Double] = ["koi-mosaic": 2, "night-reef": 2.4, "dither-dunes": 1.7, "dither-dunes-night": 1.7, "paper-garden": 2.2, "paper-garden-kraft": 2.2, "blueprint": 2, "vector-range": 1.6]

    /// Construit le décor pour un écran de `width` sur `height` points.
    public func scene(width: Double, height: Double) -> SceneGraph {
        let density = SceneTheme.densities[id] ?? SceneTheme.unitsPerPoint
        let w = (width * density).rounded(), h = (height * density).rounded()
        var scene = SceneTheme.builders[id]?(w, h) ?? SceneGraph(width: w, height: h)
        scene.pointsPerUnit = width / w
        return scene
    }

    /// Le décor à sa taille d'origine (1600 sur 1000), pour le comparer à
    /// theme-examples. Seuls les décors encore à l'identique en ont une.
    public func original() -> SceneGraph? {
        SceneTheme.originals[id]?()
    }

    public static func named(_ id: String) -> SceneTheme? { all.first { $0.id == id } }

    private static func theme(_ id: String, _ title: String, _ window: Window, twin: String? = nil, blur: Double, tint: String, opacity: Double) -> SceneTheme {
        SceneTheme(id: id, title: title, window: window, twin: twin, glass: Glass(blur: blur, tint: RGBA(tint), opacity: opacity))
    }

    /// Les décors, dans l'ordre où on les propose.
    public static let all: [SceneTheme] = [
        theme("aurora-snow", "Aurora Snow", .dark, blur: 18, tint: "#14123a", opacity: 0.3),
        theme("aurora", "Aurora", .dark, blur: 18, tint: "#14123a", opacity: 0.3),
        theme("snow-pines", "Snow Pines", .dark, blur: 16, tint: "#14143a", opacity: 0.5),
        theme("honu-lagoon", "Honu Lagoon", .light, blur: 7, tint: "#e6fbff", opacity: 0.42),
        theme("koi-mosaic", "Koi Mosaic", .light, blur: 12, tint: "#eef8f1", opacity: 0.36),
        theme("halftone-dawn", "Halftone Dawn", .light, twin: "halftone-dusk", blur: 14, tint: "#f6ead9", opacity: 0.55),
        theme("halftone-dusk", "Halftone Dusk", .dark, twin: "halftone-dawn", blur: 14, tint: "#1f2336", opacity: 0.5),
        theme("plotter-tide", "Plotter Tide", .light, twin: "plotter-tide-night", blur: 0, tint: "#f4efe4", opacity: 0.32),
        theme("plotter-tide-night", "Plotter Tide, Night", .dark, twin: "plotter-tide", blur: 0, tint: "#141a27", opacity: 0.32),
        theme("dither-dunes", "Dither Dunes", .light, twin: "dither-dunes-night", blur: 18, tint: "#f1e8d6", opacity: 0.34),
        theme("dither-dunes-night", "Dither Dunes Night", .dark, twin: "dither-dunes", blur: 18, tint: "#1c1712", opacity: 0.4),
        theme("paper-garden", "Paper Garden", .light, twin: "paper-garden-kraft", blur: 16, tint: "#fbf6ec", opacity: 0.5),
        theme("paper-garden-kraft", "Paper Garden, Kraft", .dark, twin: "paper-garden", blur: 16, tint: "#35312a", opacity: 0.5),
        theme("night-reef", "Night Reef", .dark, blur: 14, tint: "#0a1430", opacity: 0.4),
        theme("braille-stars", "Braille Stars", .dark, blur: 20, tint: "#0a1430", opacity: 0.3),
        theme("teletext-clouds", "Block Clouds", .dark, blur: 12, tint: "#0d173f", opacity: 0.34),
        theme("vector-range", "Vector Range", .dark, blur: 22, tint: "#0e2f27", opacity: 0.42),
        theme("departure-board", "Departure Board", .dark, blur: 14, tint: "#1a120b", opacity: 0.34),
        theme("blueprint", "Blueprint", .dark, blur: 14, tint: "#0c2444", opacity: 0.42),
        theme("deep-water", "Deep Water", .dark, blur: 14, tint: "#062c3a", opacity: 0.34),
        theme("ember", "Ember", .dark, blur: 12, tint: "#2a0d12", opacity: 0.3),
    ]

    /// Les vingt décors de theme-examples, et l'aurore sous la neige du site.
    static let builders: [String: @Sendable (Double, Double) -> SceneGraph] = [
        "aurora": Classic.aurora,
        "deep-water": Classic.deepWater,
        "ember": Classic.ember,
        "snow-pines": SnowPines.build,
        "honu-lagoon": HonuLagoon.build,
        "koi-mosaic": KoiMosaic.build,
        "night-reef": NightReef.build,
        "braille-stars": BrailleStars.build,
        "teletext-clouds": TeletextClouds.build,
        "departure-board": DepartureBoard.build,
        "dither-dunes": DitherDunes.build(DitherDunes.day),
        "dither-dunes-night": DitherDunes.build(DitherDunes.night),
        "halftone-dawn": Halftone.build(Halftone.dawn),
        "halftone-dusk": Halftone.build(Halftone.dusk),
        "plotter-tide": PlotterTide.build(PlotterTide.day),
        "plotter-tide-night": PlotterTide.build(PlotterTide.night),
        "paper-garden": PaperGarden.build(0),
        "paper-garden-kraft": PaperGarden.build(1),
        "blueprint": Blueprint.build,
        "vector-range": VectorRange.build,
        "aurora-snow": AuroraSnow.build,
    ]

    static let originals: [String: @Sendable () -> SceneGraph] = [
        "aurora": Classic.auroraOriginal,
        "deep-water": Classic.deepWaterOriginal,
        "ember": Classic.emberOriginal,
        "snow-pines": SnowPines.original,
        "honu-lagoon": HonuLagoon.original,
        "koi-mosaic": KoiMosaic.original,
        "night-reef": NightReef.original,
        "braille-stars": BrailleStars.original,
        "teletext-clouds": TeletextClouds.original,
        "departure-board": DepartureBoard.original,
        "dither-dunes": DitherDunes.original(DitherDunes.day),
        "dither-dunes-night": DitherDunes.original(DitherDunes.night),
        "halftone-dawn": Halftone.original(Halftone.dawn),
        "halftone-dusk": Halftone.original(Halftone.dusk),
        "plotter-tide": PlotterTide.original(PlotterTide.day),
        "plotter-tide-night": PlotterTide.original(PlotterTide.night),
        "paper-garden": PaperGarden.original(0),
        "paper-garden-kraft": PaperGarden.original(1),
        "blueprint": Blueprint.original,
        "vector-range": VectorRange.original,
    ]
}
