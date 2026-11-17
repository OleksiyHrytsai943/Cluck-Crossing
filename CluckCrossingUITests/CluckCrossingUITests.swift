import XCTest

final class CluckCrossingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"] + extra
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @discardableResult
    private func waitFor(_ id: String, timeout: TimeInterval = 8) -> XCUIElement {
        let e = element(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "\(id) did not appear")
        return e
    }

    private func digits(_ s: String) -> Int {
        Int(s.filter(\.isNumber)) ?? -1
    }

    private func coins() -> Int {
        digits(element("coins.badge").value as? String ?? "")
    }

    private func back() {
        element("back.button").tap()
        waitFor("corner.screen")
    }

    // MARK: Corner & navigation

    func testCornerShowsMainActions() {
        launch()
        waitFor("corner.screen")
        XCTAssertTrue(element("corner.walk").exists)
        XCTAssertTrue(element("coins.badge").exists)
        XCTAssertTrue(element("corner.shift").exists)
        for sign in ["timetable", "roster", "vending", "henhouse", "billboard", "rulebook"] {
            XCTAssertTrue(element("sign.\(sign)").exists, "missing sign \(sign)")
        }
    }

    func testEverySignOpensItsSectionAndReturns() {
        launch()
        waitFor("corner.screen")
        let screens = ["timetable": "timetable.screen", "roster": "roster.screen", "vending": "vending.screen", "henhouse": "henhouse.screen",
                       "billboard": "billboard.screen", "rulebook": "rulebook.screen"]
        for (sign, screen) in screens {
            element("sign.\(sign)").tap()
            waitFor(screen)
            back()
        }
    }

    func testLockedModesExplainThemselves() {
        launch()
        waitFor("corner.nightRun").tap()
        let toast = waitFor("toast")
        XCTAssertTrue(toast.label.hasPrefix("Clear all of Sleepy Lane"))
        XCTAssertFalse(element("game.screen").exists)
    }

    // MARK: Shop & hens

    func testBuyingAnUpgradeSpendsCoinsAndRaisesLevel() {
        launch(["--coins=1000"])
        waitFor("sign.vending").tap()
        waitFor("vending.screen")
        let before = coins()
        element("vending.buy.coolFeet").tap()
        let level = element("vending.level.coolFeet")
        XCTAssertTrue(level.waitForExistence(timeout: 3))
        XCTAssertEqual(level.value as? String, "1")
        XCTAssertLessThan(coins(), before)
    }

    func testBuyingWithoutCoinsIsRefused() {
        launch(["--coins=5"])
        waitFor("sign.vending").tap()
        element("vending.buy.coolFeet").tap()
        let toast = waitFor("toast")
        XCTAssertTrue(toast.label.hasPrefix("Not enough coins"))
        XCTAssertEqual(element("vending.level.coolFeet").value as? String, "0")
        XCTAssertEqual(coins(), 5)
    }

    func testAdoptingAndChoosingAHen() {
        launch(["--coins=5000"])
        waitFor("sign.henhouse").tap()
        waitFor("henhouse.screen")
        element("hen.window.dot").tap()
        element("hen.action").tap()
        XCTAssertTrue(waitFor("toast").label.contains("Dot moved in"))
        element("hen.window.pepper").tap()
        element("hen.action").tap()
        XCTAssertTrue(waitFor("toast").label.contains("Pepper is ready"))
    }

    // MARK: Top Players

    func testTopPlayersShowsRosterAndClaimsLampReward() {
        launch(["--coins=100", "--lamps=3"])
        waitFor("corner.shift").tap()
        waitFor("roster.screen")
        XCTAssertTrue(element("roster.web").exists)
        let heading = app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'TOP 5'")).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 30), "roster HTML did not render")
        let claim = element("roster.claim.3")
        XCTAssertEqual(claim.value as? String, "Ready")
        claim.tap()
        XCTAssertTrue(waitFor("toast").label.hasPrefix("+120 coins"))
        XCTAssertEqual(coins(), 220)
        XCTAssertEqual(element("roster.claim.5").value as? String, "Locked")
        back()
    }

    // MARK: Onboarding & settings

    func testTutorialWalksThroughAllPages() {
        launch(["--show-tutorial"])
        waitFor("tutorial.screen")
        for _ in 0..<6 { element("tutorial.next").tap() }
        waitFor("corner.screen")
        XCTAssertFalse(element("tutorial.screen").exists)
    }

    func testResetProgressFromSettings() {
        launch(["--cleared=6", "--coins=900"])
        waitFor("corner.settings").tap()
        waitFor("settings.reset").tap()
        app.alerts.buttons["Reset"].tap()
        element("settings.done").tap()
        waitFor("corner.screen")
        XCTAssertEqual(coins(), 150)
    }

    // MARK: Runs

    func testDistrictCardThenRunStarts() {
        launch()
        waitFor("corner.walk")
        // First crossing of a district: intro card first (intros are pre-seen only when --cleared is used).
        element("corner.walk").tap()
        if element("district.card").waitForExistence(timeout: 2) {
            element("district.start").tap()
        }
        waitFor("game.screen")
        let pause = element("game.pause")
        expectation(for: NSPredicate(format: "isHittable == true AND isEnabled == true"), evaluatedWith: pause)
        waitForExpectations(timeout: 8)
    }

    func testPauseResumeAndEndRun() {
        launch(["--cleared=1"])
        waitFor("corner.walk").tap()
        waitFor("game.screen")
        let pause = element("game.pause")
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: pause)
        waitForExpectations(timeout: 8)
        pause.tap()
        waitFor("pause.resume").tap()
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: pause)
        waitForExpectations(timeout: 4)
        pause.tap()
        waitFor("pause.quit").tap()
        waitFor("result.screen")
        element("result.home").tap()
        waitFor("corner.screen", timeout: 6)
    }

    func testRoostIsRefusedOnTheRoad() {
        launch(["--cleared=1"])
        waitFor("corner.walk").tap()
        let pause = waitFor("game.pause")
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: pause)
        waitForExpectations(timeout: 8)
        // On the start curb the basket is empty: ROOST is not ready and banks nothing.
        let roost = element("game.roost")
        XCTAssertEqual(roost.value as? String, "Not ready")
        roost.tap()
        XCTAssertEqual(digits(element("game.score").value as? String ?? ""), 0)
        XCTAssertTrue(element("game.screen").exists)
    }

    func testAutopilotFinishesFirstCrossingAndEarnsCoins() {
        launch(["--autopilot", "--coins=0"])
        waitFor("corner.walk").tap()
        if element("district.card").waitForExistence(timeout: 2) { element("district.start").tap() }
        waitFor("result.screen", timeout: 90)
        XCTAssertTrue(element("result.coins").exists)
        element("result.home").tap()
        waitFor("corner.screen", timeout: 6)
        XCTAssertGreaterThan(coins(), 0)
    }

    // MARK: Screenshot tour (attachments used for the site)

    func testTour() {
        launch(["--cleared=9", "--coins=4200", "--autopilot", "--lamps=4"])
        shot("01-corner", wait: "corner.screen")
        element("sign.timetable").tap(); shot("02-timetable", wait: "timetable.screen"); back()
        element("sign.vending").tap(); shot("03-vending", wait: "vending.screen"); back()
        element("sign.henhouse").tap(); shot("04-henhouse", wait: "henhouse.screen"); back()
        element("sign.roster").tap(); shot("10-top-players", wait: "roster.screen"); sleep(1); back()
        element("sign.rulebook").tap(); shot("05-rulebook", wait: "rulebook.screen"); back()
        element("corner.walk").tap()
        waitFor("game.screen")
        sleep(5); shot("06-run")
        sleep(4); shot("07-run")
        waitFor("result.screen", timeout: 120)
        sleep(1); shot("08-camera")
        element("result.home").tap()
        element("sign.billboard").tap(); shot("09-billboard", wait: "billboard.screen")
    }

    private func shot(_ name: String, wait id: String? = nil) {
        if let id { waitFor(id) }
        sleep(1)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
