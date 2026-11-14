import Foundation

// Aurora Snow : le décor que le reel du site avait déjà, aurore et neige. Les
// rideaux d'Aurora, et par-dessus la neige en ASCII de Snow Pines, qui tombe
// partout, plus dense sur les bords.

enum AuroraSnow {
    static func build(width: Double, height: Double) -> Scene {
        var scene = Classic.aurora(width: width, height: height)
        let pines = SnowPines(width: width, height: height, layout: .portrait(width, height))
        let layout = pines.layout
        var faint = SnowPines.faint
        faint.density = layout.faintDensity * 1.4
        faint.rows = layout.snowRows[0]
        var middle = SnowPines.middleSnow
        middle.none = layout.middleNone
        middle.rows = layout.snowRows[1]
        var bright = SnowPines.bright
        bright.none = layout.brightNone
        bright.rows = layout.snowRows[2]
        let snow = pines.snowLayer(faint) + pines.snowLayer(middle) + pines.snowLayer(bright)
        // La neige passe devant la crête et sous le voile du milieu.
        let calm = scene.nodes.removeLast()
        scene.add(snow)
        scene.add(calm)
        return scene
    }
}
