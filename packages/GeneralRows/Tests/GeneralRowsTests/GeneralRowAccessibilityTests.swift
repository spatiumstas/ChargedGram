import XCTest
import AppKit
import TGUIKit
import TelegramTheme
@testable import GeneralRows

final class GeneralRowAccessibilityTests: XCTestCase {
    private let width: CGFloat = 400
    private var windows: [NSWindow] = []

    override func setUp() {
        super.setUp()
        UITestBootstrap.install()
        TGUIKitAccessibility.isEnabled = true
    }

    override func tearDown() {
        for window in windows {
            window.contentView = nil
            window.close()
        }
        windows.removeAll()
        super.tearDown()
    }

    private func makeRow(_ type: GeneralInteractedType, description: String? = nil, enabled: Bool = true, action: @escaping () -> Void = {}) -> (GeneralInteractedRowItem, GeneralInteractedRowView) {
        let item = GeneralInteractedRowItem(NSMakeSize(width, 50), stableId: 0, name: "Notifications", description: description, type: type, viewType: .singleItem, action: action, enabled: enabled)
        _ = item.makeSize(width, oldWidth: 0)
        let row = GeneralInteractedRowView(frame: NSMakeRect(0, 0, width, item.height))
        row.set(item: item, animated: false)
        row.layout()
        let window = SnapshotWindow(contentRect: row.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = row
        windows.append(window)
        return (item, row)
    }

    func testNextRowIsOneLabeledButton() {
        let (_, row) = makeRow(.next)
        XCTAssertTrue(row.isAccessibilityElement())
        XCTAssertEqual(row.accessibilityRole(), .button)
        XCTAssertEqual(row.accessibilityLabel(), "Notifications")
        XCTAssertEqual(row.accessibilityChildren()?.count, 0)
        XCTAssertFalse(row.containerView.isAccessibilityElement())
        XCTAssertEqual(AccessibilityAudit.audit(row), [])
    }

    func testContextRowReadsItsValueAndDescription() {
        let (_, row) = makeRow(.context("Everybody"), description: "Who can see your phone number")
        XCTAssertEqual(row.accessibilityValue() as? String, "Everybody")
        XCTAssertEqual(row.accessibilityHelp(), "Who can see your phone number")
    }

    func testSwitchRowIsACheckboxThatToggles() {
        var calls = 0
        let (item, row) = makeRow(.switchable(false), action: { calls += 1 })
        XCTAssertEqual(row.accessibilityRole(), .checkBox)
        XCTAssertEqual(row.accessibilityValue() as? NSNumber, 0)
        XCTAssertTrue(row.accessibilityPerformPress())
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(item.accessibilityToggleState, true)
        XCTAssertEqual(row.accessibilityValue() as? NSNumber, 1)
        XCTAssertEqual(AccessibilityAudit.audit(row), [])
    }

    func testSelectableRowIsARadioButton() {
        let (_, row) = makeRow(.selectable(true))
        XCTAssertEqual(row.accessibilityRole(), .radioButton)
        XCTAssertEqual(row.accessibilityValue() as? NSNumber, 1)
    }

    func testDisabledRowIsReportedDisabled() {
        var calls = 0
        let (_, row) = makeRow(.next, enabled: false, action: { calls += 1 })
        XCTAssertFalse(row.isAccessibilityEnabled())
        _ = row.accessibilityPerformPress()
        XCTAssertEqual(calls, 0)
    }
}
