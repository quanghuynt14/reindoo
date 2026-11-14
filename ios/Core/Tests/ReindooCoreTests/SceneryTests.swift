import Foundation
import Testing
@testable import ReindooCore

/// Le moteur des décors : ce que l'app peint doit être ce que le navigateur
/// peignait. Ces tests tiennent les règles de CSS et de SVG que les décors
/// utilisent. La comparaison pixel à pixel avec theme-examples se fait à la
/// main, avec `reindoo-cli scene <thème> original <secondes>`.
@Suite struct SceneryEngine {
    @Test func pathsReadRelativeCommandsAndSmoothCurves() {
        let path = PathData(svg: "M10 20 l5-5 h10 v10 q5 5 10 0 t10 0 z")
        #expect(path.commands == [
            .move(10, 20), .line(15, 15), .line(25, 15), .line(25, 25),
            .quad(30, 30, 35, 25), .quad(40, 20, 45, 25), .close,
        ])
    }

    @Test func numbersFollowEachOtherWithoutSeparators() {
        let path = PathData(svg: "M-92 0l-30 6l28 6z")
        #expect(path.commands == [.move(-92, 0), .line(-122, 6), .line(-94, 12), .close])
    }

    @Test func anArcEndsWhereItWasAsked() {
        let path = PathData(svg: "M0 0 A10 10 0 0 1 20 0")
        guard case .cubic(_, _, _, _, let x, let y)? = path.commands.last else {
            Issue.record("un arc doit devenir des courbes")
            return
        }
        #expect(abs(x - 20) < 1e-9 && abs(y) < 1e-9)
        // Un demi-cercle de rayon 10 : la longueur vaut 10π.
        #expect(abs(path.length - 10 * .pi) < 0.05)
    }

    @Test func stepsJumpAtTheEndOfEachStep() {
        #expect(Timing.steps(4).apply(0.24) == 0)
        #expect(Timing.steps(4).apply(0.26) == 0.25)
        #expect(Timing.steps(4).apply(0.99) == 0.75)
    }

    @Test func easeInOutIsSymmetric() {
        let early = Timing.easeInOut.apply(0.2), late = Timing.easeInOut.apply(0.8)
        #expect(abs(early + late - 1) < 1e-6)
        #expect(early < 0.2)
    }

    @Test func aNegativeDelayStartsMidway() {
        let slide = SceneAnimation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(100, 0))], duration: 10, delay: -5, timing: .linear)
        #expect(slide.value(of: .transform, at: 0, base: .ops([])) == .ops([.translate(50, 0)]))
    }

    @Test func aPositiveDelayLeavesTheBaseUntilItStarts() {
        let fade = SceneAnimation.between([.opacity: .n(0)], [.opacity: .n(1)], duration: 10, delay: 3, timing: .linear)
        #expect(fade.value(of: .opacity, at: 1, base: .n(0.4)) == nil)
        #expect(fade.value(of: .opacity, at: 8, base: .n(0.4)) == .n(0.5))
    }

    @Test func alternateRunsBackOnOddIterations() {
        let swing = SceneAnimation.between([.opacity: .n(0)], [.opacity: .n(1)], duration: 10, direction: .alternate, timing: .linear)
        #expect(swing.value(of: .opacity, at: 12, base: .n(1)) == .n(0.8))
        let back = swing.directed(.alternateReverse)
        #expect(back.value(of: .opacity, at: 2, base: .n(1)) == .n(0.8))
    }

    @Test func aPropertyMissingFromAKeyframeIsInterpolatedOverTheOthers() {
        // Comme les bulles : l'opacité a quatre images, la position deux.
        let rise = SceneAnimation([
            .init(0, [.transform: .t(.translate(0, 0)), .opacity: .n(0)]),
            .init(0.12, [.opacity: .n(1)]),
            .init(1, [.transform: .t(.translate(0, -100)), .opacity: .n(0)]),
        ], duration: 100, timing: .linear)
        #expect(rise.value(of: .transform, at: 50, base: .ops([])) == .ops([.translate(0, -50)]))
        #expect(rise.value(of: .opacity, at: 6, base: .n(1)) == .n(0.5))
    }

    @Test func anAnimatedTransformReplacesTheFixedOne() {
        var attributes = Attributes()
        attributes.transform = [.translate(500, 500)]
        attributes.animations = [SceneAnimation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(10, 0))], duration: 10, timing: .linear)]
        #expect(attributes.matrix(at: 5) == Affine(tx: 5, ty: 0))
    }

    @Test func rotationTurnsAroundTheOrigin() {
        var attributes = Attributes()
        attributes.origin = Point(10, 10)
        attributes.animations = [SceneAnimation.between([.transform: .t(.rotate(0))], [.transform: .t(.rotate(180))], duration: 1, timing: .linear)]
        let half = attributes.matrix(at: 0.9999999)
        let moved = half.apply(Point(10, 10))
        #expect(abs(moved.x - 10) < 1e-6 && abs(moved.y - 10) < 1e-6)
    }

    @Test func anAnimatedFillOpacityPassesToChildrenThatSetNone() {
        var scene = SceneGraph(width: 10, height: 10)
        let settle = SceneAnimation.between([.fillOpacity: .n(0)], [.fillOpacity: .n(1)], duration: 10, timing: .linear)
        scene.add(.group([
            .rect(0, 0, 1, 1).fill("#ffffff"),
            .rect(0, 0, 1, 1).fill("#ffffff", opacity: 0.9),
        ]).animate(settle))
        var recorder = Recorder()
        scene.paint(at: 5, into: &recorder)
        #expect(recorder.alphas == [0.5, 0.9])
    }

    @Test func aMaskTurnsLuminanceIntoAlpha() {
        let scene = SceneGraph(width: 10, height: 10)
        let grey = scene.resolve(.color(RGBA(0.5, 0.5, 0.5)), opacity: 1, bounds: nil, mask: true)
        guard case .color(let color)? = grey else {
            Issue.record("une couleur reste une couleur")
            return
        }
        #expect(color.r == 1 && abs(color.a - 0.5) < 1e-9)
    }

    @Test func theSnowPinesHashMatchesJavaScript() {
        // Valeurs tirées de snow-pines.ts sous Node.
        #expect(SnowPines.hash(0, 0, 0) == 0)
        #expect(SnowPines.hash(12, 3, 11) == 0.67127)
    }

    @Test(arguments: ["snow-pines", "koi-mosaic", "plotter-tide", "braille-stars"])
    func aPlannedFrameIsTheWholeFrame(id: String) throws {
        let scene = try #require(SceneTheme.named(id)).scene(width: 390, height: 844)
        var whole = OpRecorder()
        scene.paint(at: 12.5, into: &whole)
        var planned = 0
        for part in scene.plan(motion: true).parts {
            switch part {
            case .still(let ops): planned += ops.reduce(0) { $0 + $1.count }
            case .live(let nodes, let style): planned += scene.record(nodes, style, at: 12.5).reduce(0) { $0 + $1.count }
            }
        }
        #expect(planned == whole.ops.reduce(0) { $0 + $1.count })
    }

    @Test func aPlannedPathKeepsItsKeyFromFrameToFrame() throws {
        // L'app garde la géométrie sous ces numéros : un numéro nomme toujours
        // la même forme. Ce qui est invisible à un instant est sauté : la liste
        // change, pas le sens des numéros.
        let plan = try #require(SceneTheme.named("koi-mosaic")).scene(width: 390, height: 844).plan(motion: true)
        func paths(at time: Double) -> [(Int?, PathData)] {
            func walk(_ ops: [DrawOp]) -> [(Int?, PathData)] {
                ops.flatMap { op -> [(Int?, PathData)] in
                    switch op {
                    case .layer(_, let inner, let mask): walk(inner) + walk(mask ?? [])
                    case .fill(let path, _, _), .stroke(let path, _, _): [(path.key, path)]
                    case .glyphs: []
                    }
                }
            }
            return plan.parts.flatMap { part -> [(Int?, PathData)] in
                if case .live(let nodes, let style) = part { return walk(plan.scene.record(nodes, style, at: time)) }
                return []
            }
        }
        var seen: [Int: PathData] = [:]
        for time in [3.0, 47.5, 120.25] {
            for (key, path) in paths(at: time) {
                let key = try #require(key)
                if let earlier = seen[key] { #expect(earlier == path, "le numéro \(key) a changé de forme") }
                seen[key] = path
            }
        }
        #expect(!seen.isEmpty)
    }

    @Test func withoutMotionNothingIsLive() throws {
        let plan = try #require(SceneTheme.named("snow-pines")).scene(width: 390, height: 844).plan(motion: false)
        #expect(plan.summary.liveNodes == 0)
        #expect(plan.summary.stillParts == 1)
    }

    @Test func everyThemeBuildsAPortraitScene() {
        for theme in SceneTheme.all where SceneTheme.builders[theme.id] != nil {
            let scene = theme.scene(width: 390, height: 844)
            #expect(!scene.nodes.isEmpty, "\(theme.id)")
            #expect(abs(scene.width * scene.pointsPerUnit - 390) < 1e-9)
        }
    }
}

/// Garde ce qu'on lui peint, pour vérifier les valeurs résolues.
struct Recorder: ScenePainter {
    var alphas: [Double] = []
    mutating func push(_ layer: Layer) {}
    mutating func beginMask() {}
    mutating func pop() {}
    mutating func fill(_ path: PathData, _ paint: ResolvedPaint, evenOdd: Bool) {
        if case .color(let color) = paint { alphas.append(color.a) }
    }
    mutating func stroke(_ path: PathData, _ paint: ResolvedPaint, _ style: StrokeSpec) {}
    mutating func glyphs(_ glyphs: Glyphs, _ paint: ResolvedPaint, size: Double, weight: Int) {}
}
