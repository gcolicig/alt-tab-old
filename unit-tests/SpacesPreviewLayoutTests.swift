import XCTest

class SpacesPreviewLayoutTests: XCTestCase {
    private typealias Display = SpacesPreviewLayout.Display

    /// The measured case from the Menubar ordering: a wider screen centred above the laptop starts further left.
    func testAWiderDisplayCentredAboveTheLaptopComesFirst() {
        let rows = SpacesPreviewLayout.rows([
            Display(id: "laptop", frame: CGRect(x: 0, y: 0, width: 1512, height: 982)),
            Display(id: "top", frame: CGRect(x: -900, y: 982, width: 3360, height: 1890)),
        ])
        XCTAssertEqual(rows, [["top"], ["laptop"]])
    }

    func testDisplaysSideBySideShareOneRowLeftToRight() {
        let rows = SpacesPreviewLayout.rows([
            Display(id: "right", frame: CGRect(x: 1512, y: -200, width: 2560, height: 1440)),
            Display(id: "left", frame: CGRect(x: 0, y: 0, width: 1512, height: 982)),
        ])
        XCTAssertEqual(rows, [["left", "right"]])
    }

    func testTwoBelowAndOneAbove() {
        let rows = SpacesPreviewLayout.rows([
            Display(id: "bottomRight", frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080)),
            Display(id: "top", frame: CGRect(x: 960, y: 1080, width: 1920, height: 1080)),
            Display(id: "bottomLeft", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
        ])
        XCTAssertEqual(rows, [["top"], ["bottomLeft", "bottomRight"]])
    }

    /// A portrait display next to a landscape one overlaps it by the landscape height, so they share a row.
    func testAPortraitDisplayWithNegativeCoordinatesSitsBesideTheMainOne() {
        let rows = SpacesPreviewLayout.rows([
            Display(id: "main", frame: CGRect(x: 0, y: 0, width: 2560, height: 1440)),
            Display(id: "portrait", frame: CGRect(x: -1440, y: -600, width: 1440, height: 2560)),
        ])
        XCTAssertEqual(rows, [["portrait", "main"]])
    }

    func testQuartzFrameFlipsAroundThePrimaryScreen() {
        let quartz = SpacesPreviewLayout.quartzFrame(cocoaFrame: CGRect(x: -900, y: 982, width: 3360, height: 1890), primaryScreenHeight: 982)
        XCTAssertEqual(quartz, CGRect(x: -900, y: -1890, width: 3360, height: 1890))
    }

    func testWindowRectScalesIntoTheTile() {
        let rect = SpacesPreviewLayout.windowRect(windowFrame: CGRect(x: 100, y: 50, width: 500, height: 250),
                                                  screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 500),
                                                  tileSize: CGSize(width: 100, height: 50))
        XCTAssertEqual(rect, CGRect(x: 10, y: 5, width: 50, height: 25))
    }

    func testWindowRectRespectsTheScreenOrigin() {
        let rect = SpacesPreviewLayout.windowRect(windowFrame: CGRect(x: -900, y: -1890, width: 336, height: 189),
                                                  screenFrame: CGRect(x: -900, y: -1890, width: 3360, height: 1890),
                                                  tileSize: CGSize(width: 160, height: 90))
        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 16, height: 9))
    }

    func testAWindowLargerThanTheScreenIsClipped() {
        let rect = SpacesPreviewLayout.windowRect(windowFrame: CGRect(x: -100, y: -100, width: 3000, height: 3000),
                                                  screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 500),
                                                  tileSize: CGSize(width: 100, height: 50))
        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 100, height: 50))
    }

    func testAWindowOffTheScreenGivesNothing() {
        XCTAssertNil(SpacesPreviewLayout.windowRect(windowFrame: CGRect(x: 2000, y: 0, width: 100, height: 100),
                                                    screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 500),
                                                    tileSize: CGSize(width: 100, height: 50)))
    }
}
