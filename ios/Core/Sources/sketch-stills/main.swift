// Peint chaque dessin de l'app en JPEG, avant la construction de l'app.
// Usage : sketch-stills <dossier>. Le téléphone n'aura plus qu'à les afficher.
#if canImport(ImageIO)
import Foundation
import ImageIO
import ReindooCore
import UniformTypeIdentifiers

let folder = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Sketches")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
var failed = false
// Chaque dessin se peint seul : on les répartit sur tous les cœurs.
let stills = Still.all
let lock = NSLock()
DispatchQueue.concurrentPerform(iterations: stills.count) { i in
    let still = stills[i]
    let url = folder.appendingPathComponent(still.name + ".jpg")
    guard let image = SketchPainter.paint(still.plan()),
          let file = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
        lock.withLock { failed = true; print("raté : \(still.name)") }
        return
    }
    CGImageDestinationAddImage(file, image, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
    if !CGImageDestinationFinalize(file) { lock.withLock { failed = true; print("raté : \(still.name)") } }
}
print("\(stills.count) dessins dans \(folder.path)")
if failed { exit(1) }
#else
print("sketch-stills : Core Graphics manque ici (macOS seulement).")
#endif
