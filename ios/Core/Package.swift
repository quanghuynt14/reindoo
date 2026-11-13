// swift-tools-version: 6.0
import PackageDescription

// Core : tout ce que l'app sait faire, sans rien savoir de l'écran.
// Il se construit et se teste sous Linux. S'il importe SwiftUI ou UIKit,
// l'architecture est cassée.
let package = Package(
    name: "ReindooCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReindooCore", targets: ["ReindooCore"]),
        .executable(name: "reindoo-cli", targets: ["reindoo-cli"]),
    ],
    targets: [
        // SQLite embarqué pour Linux seulement. Sur les plateformes Apple,
        // Core se lie au SQLite du système.
        .target(
            name: "CSQLite",
            cSettings: [
                .define("SQLITE_THREADSAFE", to: "1"),
                .define("SQLITE_OMIT_LOAD_EXTENSION"),
                .define("SQLITE_DQS", to: "0"),
            ]
        ),
        .target(
            name: "ReindooCore",
            dependencies: [
                .target(name: "CSQLite", condition: .when(platforms: [.linux])),
            ]
        ),
        .executableTarget(name: "reindoo-cli", dependencies: ["ReindooCore"]),
        .testTarget(name: "ReindooCoreTests", dependencies: ["ReindooCore"]),
    ]
)
