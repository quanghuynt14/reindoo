import Foundation
import Testing
@testable import ReindooCore

@Suite struct Drawing {
    @Test func theSameSeedDrawsTheSameStrokes() {
        let a = Sketch.jackal(.cross).plan(width: 120, height: 160)
        let b = Sketch.jackal(.cross).plan(width: 120, height: 160)
        let first = a.layers.flatMap(\.batches).flatMap(\.lines).prefix(200).map(\.points)
        let second = b.layers.flatMap(\.batches).flatMap(\.lines).prefix(200).map(\.points)
        #expect(first == second, "un dessin est le même sur tous les téléphones")
    }

    @Test func eachFrameRedrawsTheLinesSlightly() {
        let a = Sketch.giraffe(.calm).plan(width: 120, height: 160, frame: 0)
        let b = Sketch.giraffe(.calm).plan(width: 120, height: 160, frame: 1)
        let ink = { (plan: SketchPlan) in plan.layers.last!.batches.flatMap(\.lines).map(\.points) }
        #expect(ink(a) != ink(b), "le trait bout : chaque version est retracée")
        #expect(a.layers.count == b.layers.count)
        // Seul le contour bout : les couleurs et le papier restent, sinon l'image clignote.
        let under = { (plan: SketchPlan) in plan.layers.dropLast().flatMap(\.batches).flatMap(\.lines).map(\.points) }
        #expect(under(a) == under(b))
    }

    @Test func everyMoodHasItsLayersAndItsInk() {
        let sketches: [Sketch] = Sketch.GiraffeMood.allCases.map(Sketch.giraffe) + Sketch.JackalMood.allCases.map(Sketch.jackal) + [.together]
        for sketch in sketches {
            let plan = sketch.plan(width: 90, height: 120)
            #expect(plan.layers.count == 5, "\(sketch)")
            #expect(plan.layers.allSatisfy { !$0.batches.isEmpty || $0.blend == .normal }, "\(sketch)")
            let strokes = plan.layers.flatMap(\.batches).flatMap(\.lines)
            #expect(strokes.count > 500, "\(sketch)")
            #expect(strokes.allSatisfy { $0.width > 0 && $0.alpha >= 0 && $0.alpha <= 1 && $0.points.allSatisfy { $0.x.isFinite && $0.y.isFinite } })
        }
    }

    @Test func everyStoryAnimalIsDrawn() {
        for story in Story.all {
            for who in story.cast {
                let name = who.drawing ?? ""
                #expect(name == "giraffe" || name == "jackal" || Species(rawValue: name) != nil, "\(story.id) : \(who.name)")
            }
        }
        for species in Species.allCases {
            for mood in Sketch.AnimalMood.allCases {
                let plan = Sketch.animal(species, mood).plan(width: 90, height: 90, head: true)
                let strokes = plan.layers.flatMap(\.batches).flatMap(\.lines)
                #expect(plan.layers.count == 5 && strokes.count > 300, "\(species) \(mood)")
                #expect(strokes.allSatisfy { $0.points.allSatisfy { $0.x.isFinite && $0.y.isFinite } })
            }
        }
        // Content, on le voit : les yeux se ferment, plus de reflet dedans.
        #expect(Sketch.animal(.bear, .happy).plan(width: 90, height: 90).glints.count < Sketch.animal(.bear, .calm).plan(width: 90, height: 90).glints.count)
    }

    @Test func everyStoryHasADrawnBackdropThatFillsTheScreen() {
        for story in Story.all {
            #expect(Motif(scene: story.scene) != .dawn || story.scene == "halftone-dawn", "\(story.id) : \(story.scene)")
        }
        for motif in Motif.allCases {
            // Un téléphone plus étroit que le décor : le décor déborde, il ne laisse pas de bande vide.
            let plan = Sketch.backdrop(motif).plan(width: 90, height: 200)
            let page = plan.layers[0].batches[0].clip!.shape
            #expect(page.map(\.x).min()! <= 0 && page.map(\.x).max()! >= 90, "\(motif)")
            #expect(page.map(\.y).min()! <= 0 && page.map(\.y).max()! >= 200, "\(motif)")
            #expect(plan.layers.flatMap(\.batches).flatMap(\.lines).count > 500, "\(motif)")
        }
    }

    @Test func everyGlyphIsPencilOnly() {
        for glyph in Glyph.allCases {
            let ink = Sketch.glyph(glyph).plan(width: 60, height: 60).layers.last!.batches.flatMap(\.lines)
            #expect(ink.count > 20, "\(glyph)")
            #expect(ink.allSatisfy { $0.points.allSatisfy { (-4...64).contains($0.x) && (-4...64).contains($0.y) } }, "\(glyph)")
        }
    }

    @Test func aHeadFillsItsButton() {
        let plan = Sketch.jackal(.soft).plan(width: 100, height: 100, head: true)
        let outlines = plan.layers.last!.batches.flatMap(\.lines).flatMap(\.points)
        // La tête occupe la pastille : ses traits touchent presque les bords.
        let xs = outlines.map(\.x).filter { $0 >= 0 && $0 <= 100 }
        #expect((xs.min() ?? 100) < 25 && (xs.max() ?? 0) > 75)
    }

    @Test func thePaperEatsALightStrokeMoreThanAHeavyOne() {
        let tooth = Paper.tooth(width: 64, height: 64)
        #expect(tooth.allSatisfy { $0 >= 0 && $0 <= 1 })
        func covered(_ alpha: UInt8) -> Int {
            var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
            for i in 0..<(64 * 64) { for c in 0..<4 { pixels[i * 4 + c] = alpha } }
            pixels.withUnsafeMutableBufferPointer { Paper.bite($0, tooth: tooth, threshold: 0.3, softness: 0.3) }
            return (0..<(64 * 64)).reduce(0) { $0 + Int(pixels[$1 * 4 + 3]) }
        }
        #expect(covered(60) * 255 < covered(255) * 60, "un trait léger ne marque que les sommets du grain")
    }

    @Test func thePaperGrainHasNoSeam() {
        let t = Paper.tile
        let tooth = Paper.tooth(width: t + 2, height: 3)
        // Le carreau recommence : le pixel d'après le bord vaut celui du début,
        // et il n'y a pas de marche entre le dernier pixel et le premier.
        #expect(tooth[t] == tooth[0])
        #expect(abs(tooth[t - 1] - tooth[t]) < 0.2)
    }

    @Test func pathsAreSampledFinely() {
        let line = Shape.path("M0 0 L10 0")
        #expect(line.count >= 10 && line.last == Pt(10, 0))
        let closed = Shape.path("M0 0 L10 0 L10 10 Z")
        #expect(closed.last == Pt(0, 0))
    }
}
