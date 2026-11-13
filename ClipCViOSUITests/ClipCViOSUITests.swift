import XCTest

@MainActor
final class ClipCViOSUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--design-preview", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["设置"].waitForExistence(timeout: 15))
        return app
    }

    func testHistorySearchPauseAndDetail() {
        let app = launch()
        capture("home", app: app)
        app.buttons["暂停记录"].tap()
        XCTAssertTrue(app.staticTexts["已暂停"].exists)
        XCTAssertTrue(app.staticTexts["常用回复"].exists)
        app.buttons["继续记录"].tap()
        let search = app.textFields["history-search"]
        search.tap()
        search.typeText("ClipCV")
        XCTAssertTrue(app.staticTexts["无匹配记录"].waitForExistence(timeout: 2) == false)
        app.buttons["清除搜索"].tap()
        app.swipeDown()
        app.staticTexts["常用回复"].tap()
        XCTAssertTrue(app.buttons["更多操作"].waitForExistence(timeout: 5))
        capture("text-detail", app: app)
        app.buttons["复制"].tap()
        XCTAssertTrue(app.buttons["已复制"].exists)
    }

    func testSettingsStorageAndImage() {
        let app = launch()
        app.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        capture("settings", app: app)
        app.buttons.containing(.staticText, identifier: "当前状态").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["iCloud 同步"].waitForExistence(timeout: 5))
        capture("sync", app: app)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons.containing(.staticText, identifier: "历史与空间").firstMatch.tap()
        XCTAssertTrue(app.buttons["清空未钉选"].waitForExistence(timeout: 5))
        capture("storage", app: app)
        app.buttons["清空未钉选"].tap()
        XCTAssertEqual(app.alerts.count, 0)
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["常用回复"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["周末的海边"].exists)
        app.terminate()
        app.launch()
        app.staticTexts["周末的海边"].tap()
        XCTAssertTrue(app.buttons["原图预览"].waitForExistence(timeout: 5))
        capture("image-detail", app: app)
        app.buttons["原图预览"].tap()
        XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 5))
        capture("original-image", app: app)
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
