import XCTest

/// Les gestes qu'une capture d'écran ne prouve pas. Chaque test lance l'app
/// sur une fixture, fait le geste, et vérifie qu'elle est toujours debout.
@MainActor
final class GestureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-AppleLanguages", "(en)"]
        app.launch()
        return app
    }

    /// Le retour par glissement, du bord gauche vers la droite.
    private func swipeBack(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Une photo de l'écran, pour ce qu'on n'atteint qu'avec des gestes. Le
    /// simulateur écrit sur le disque de la machine : la CI ramasse le dossier.
    private func snap(_ name: String) {
        let folder = "/tmp/reindoo-shots"
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(folder)/gesture-\(name).png"))
    }

    private func assertAlive(_ app: XCUIApplication, _ message: String) {
        // Laisse le temps à un plantage de se produire.
        _ = app.wait(for: .notRunning, timeout: 2)
        XCTAssertEqual(app.state, .runningForeground, message)
    }

    func testSwipingBackFromAnEntryOpenedAtLaunch() {
        let app = launch("-fixture", "returning", "-open", "aller")
        XCTAssertTrue(app.staticTexts["aller"].waitForExistence(timeout: 15))

        swipeBack(app)
        assertAlive(app, "l'app a planté au retour par glissement")
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
    }

    func testSwipingBackAfterTypingAndTappingAResult() {
        let app = launch("-fixture", "returning")
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("allu")

        let row = app.buttons["allumer"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["bật, thắp"].waitForExistence(timeout: 5))

        swipeBack(app)
        assertAlive(app, "l'app a planté au retour, clavier ouvert")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
    }

    func testTheBackButtonAlsoReturns() {
        let app = launch("-fixture", "returning", "-open", "aller")
        XCTAssertTrue(app.staticTexts["aller"].waitForExistence(timeout: 15))

        app.navigationBars.buttons.firstMatch.tap()
        assertAlive(app, "l'app a planté au retour par le bouton")
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
    }

    func testSwipingBackTwiceThroughAStack() {
        let app = launch("-fixture", "returning", "-open", "allions")
        XCTAssertTrue(app.buttons["allier"].waitForExistence(timeout: 15))
        app.buttons["allier"].tap()
        XCTAssertTrue(app.staticTexts["kết hợp"].waitForExistence(timeout: 5))

        swipeBack(app)
        assertAlive(app, "l'app a planté au premier retour")
        XCTAssertTrue(app.staticTexts["aller"].waitForExistence(timeout: 5))
        swipeBack(app)
        assertAlive(app, "l'app a planté au second retour")
    }

    func testSwipingBackFromHistory() {
        let app = launch("-fixture", "returning", "-tab", "history")
        let row = app.buttons.containing(.staticText, identifier: "venir").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.staticTexts["đến"].waitForExistence(timeout: 5))

        swipeBack(app)
        assertAlive(app, "l'app a planté au retour depuis l'historique")
    }

    func testTheReelShowsMeaningsAndNeverEnds() {
        let app = launch("-fixture", "returning", "-tab", "review")
        XCTAssertTrue(app.staticTexts["aller"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Tôi đi học."].waitForExistence(timeout: 8), "le sens vient seul")
        // Les boutons tiennent au bas de la page : leur hauteur dit si la
        // page est bien calée.
        let likes = app.buttons.matching(identifier: "Like")
        let settled = likes.firstMatch.frame.midY

        app.swipeUp()
        assertAlive(app, "l'app a planté en changeant de carte")
        XCTAssertTrue(app.staticTexts["học sinh"].waitForExistence(timeout: 8), "la carte suivante se montre à son tour")
        XCTAssertEqual(app.buttons["herd"].value as? String, "right", "une carte, un saut des rennes")
        let heights = likes.allElementsBoundByIndex.map(\.frame.midY)
        XCTAssertTrue(heights.contains { abs($0 - settled) < 2 }, "la page suivante se cale comme la première : \(heights) contre \(settled)")

        // Deux touchers posent un cœur.
        app.staticTexts["élève"].firstMatch.doubleTap()
        assertAlive(app, "l'app a planté en posant un cœur")

        snap("reel-heart")

        // Quatre mots dans l'historique, et pourtant on défile bien au-delà.
        // La sixième carte est une question.
        for _ in 0..<4 { app.swipeUp() }
        let answer = app.buttons["đến"]
        XCTAssertTrue(answer.waitForExistence(timeout: 8), "la question propose le bon sens")
        sleep(1)
        snap("reel-quiz")
        answer.tap()
        sleep(1)
        snap("reel-quiz-answered")
        assertAlive(app, "l'app a planté en répondant")

        for _ in 0..<2 { app.swipeUp() }
        assertAlive(app, "l'app a planté au bout du premier tour")
        // Huitième carte : un mot du second tour, calé comme le premier.
        XCTAssertTrue(app.staticTexts["Về nhà thôi."].waitForExistence(timeout: 8), "go, au second tour, montre son sens")
        let later = likes.allElementsBoundByIndex.map(\.frame.midY)
        XCTAssertTrue(later.contains { abs($0 - settled) < 2 }, "loin dans le reel, la page se cale encore : \(later) contre \(settled)")
        snap("reel-eighth")
    }

    func testTheReelOptionsChangeTheOrder() {
        let app = launch("-fixture", "returning", "-tab", "review")
        XCTAssertTrue(app.staticTexts["aller"].waitForExistence(timeout: 15))

        app.buttons["Options"].tap()
        let oldest = app.buttons["Oldest first"]
        XCTAssertTrue(oldest.waitForExistence(timeout: 5))
        oldest.tap()
        assertAlive(app, "l'app a planté en changeant l'ordre")
        XCTAssertTrue(app.staticTexts["học sinh"].waitForExistence(timeout: 8), "le plus ancien d'abord : élève")
    }

    func testTheReindeerHopAcrossAndBack() {
        let app = launch("-fixture", "returning")
        let herd = app.buttons["herd"]
        XCTAssertTrue(herd.waitForExistence(timeout: 15))
        XCTAssertEqual(herd.value as? String, "left")

        herd.tap()
        assertAlive(app, "l'app a planté quand les rennes ont sauté")
        XCTAssertEqual(herd.value as? String, "right")

        herd.tap()
        XCTAssertEqual(herd.value as? String, "left", "un second toucher les ramène")
    }
}
