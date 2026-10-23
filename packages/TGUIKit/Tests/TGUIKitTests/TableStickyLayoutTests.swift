import AppKit
import XCTest
@testable import TGUIKit

private final class LayoutPrimaryHeader: TableStickItem {}
private final class LayoutSecondaryHeader: TableStickItem {}

private final class LayoutScanCounts {
    var primary = 0
    var secondary = 0
}

private final class LayoutCountedItem: TableRowItem {
    let counts: LayoutScanCounts
    init(id: Int, counts: LayoutScanCounts) {
        self.counts = counts
        super.init(.zero, stableId: id)
    }
    override func isKind(of aClass: AnyClass) -> Bool {
        if ObjectIdentifier(aClass) == ObjectIdentifier(LayoutPrimaryHeader.self) { counts.primary += 1 }
        if ObjectIdentifier(aClass) == ObjectIdentifier(LayoutSecondaryHeader.self) { counts.secondary += 1 }
        return super.isKind(of: aClass)
    }
}

final class TableStickyLayoutTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TGUIKitTestBootstrap.install()
    }

    private func makeTable() -> (TableView, LayoutScanCounts) {
        let table = TableView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        let counts = LayoutScanCounts()
        for id in 0..<40 {
            if id % 10 == 0 { _ = table.addItem(item: LayoutPrimaryHeader(.zero)) }
            else if id % 10 == 5 { _ = table.addItem(item: LayoutSecondaryHeader(.zero)) }
            else { _ = table.addItem(item: LayoutCountedItem(id: id, counts: counts)) }
        }
        table.set(stickClass: LayoutPrimaryHeader.self, handler: { _ in })
        table.setSecondary(stickClass: LayoutSecondaryHeader.self, handler: { _ in })
        table.updateStickAfterScroll(false)
        XCTAssertGreaterThan(counts.primary, 0)
        XCTAssertGreaterThan(counts.secondary, 0)
        counts.primary = 0
        counts.secondary = 0
        return (table, counts)
    }

    func testRepeatedLayoutDoesNotRescanUnchangedHeaderIndexes() {
        let (table, counts) = makeTable()
        for _ in 0..<20 {
            table.layout()
            table.updateStickAfterScroll(false)
        }
        XCTAssertEqual(table.count, 40)
        XCTAssertEqual(counts.primary, 0)
        XCTAssertEqual(counts.secondary, 0)
    }

    func testRealInsertionAndRemovalStillInvalidateBothIndexes() {
        let (table, counts) = makeTable()
        _ = table.insert(item: LayoutPrimaryHeader(.zero), at: 0)
        table.layout()
        table.updateStickAfterScroll(false)
        XCTAssertGreaterThan(counts.primary, 0)
        XCTAssertGreaterThan(counts.secondary, 0)
        counts.primary = 0
        counts.secondary = 0
        table.remove(at: 0)
        table.layout()
        table.updateStickAfterScroll(false)
        XCTAssertGreaterThan(counts.primary, 0)
        XCTAssertGreaterThan(counts.secondary, 0)
        counts.primary = 0
        counts.secondary = 0
        table.layout()
        table.updateStickAfterScroll(false)
        XCTAssertEqual(counts.primary, 0)
        XCTAssertEqual(counts.secondary, 0)
    }

    func testHeaderClassChangesStillRefreshTheMatchingIndex() {
        let (table, counts) = makeTable()
        table.set(stickClass: LayoutSecondaryHeader.self, handler: { _ in })
        table.updateStickAfterScroll(false)
        XCTAssertGreaterThan(counts.secondary, 0)
        counts.primary = 0
        counts.secondary = 0
        table.setSecondary(stickClass: LayoutPrimaryHeader.self, handler: { _ in })
        table.updateStickAfterScroll(false)
        XCTAssertGreaterThan(counts.primary, 0)
        counts.primary = 0
        counts.secondary = 0
        table.layout()
        table.updateStickAfterScroll(false)
        XCTAssertEqual(counts.primary, 0)
        XCTAssertEqual(counts.secondary, 0)
    }
}
