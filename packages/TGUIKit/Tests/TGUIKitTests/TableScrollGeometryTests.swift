import AppKit
import XCTest
@testable import TGUIKit

private final class ScrollGeometryTableSpy: TGFlipableTableView {
    var rangeQueries = 0
    override func rows(in rect: NSRect) -> NSRange {
        rangeQueries += 1
        return NSRange(location: 0, length: 0)
    }
}

private final class ScrollGeometryHeader: TableStickItem {}
private final class ScrollGeometrySecondaryHeader: TableStickItem {}

final class TableScrollGeometryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TGUIKitTestBootstrap.install()
    }

    func testAbsentStickyHeadersDoNotQueryRows() {
        let table = TableView(frame: NSRect(x: 0, y: 0, width: 320, height: 400))
        let spy = ScrollGeometryTableSpy(frame: table.bounds)
        table.tableView = spy
        for _ in 0..<20 { table.updateStickAfterScroll(false) }
        XCTAssertEqual(spy.rangeQueries, 0)
        table.set(stickClass: ScrollGeometryHeader.self, handler: { _ in })
        spy.rangeQueries = 0
        table.updateStickAfterScroll(false)
        XCTAssertEqual(spy.rangeQueries, 1)
        table.setSecondary(stickClass: ScrollGeometrySecondaryHeader.self, handler: { _ in })
        spy.rangeQueries = 0
        table.updateStickAfterScroll(false)
        XCTAssertEqual(spy.rangeQueries, 2)
        table.set(stickClass: nil, handler: { _ in })
        spy.rangeQueries = 0
        table.updateStickAfterScroll(false)
        XCTAssertEqual(spy.rangeQueries, 1)
        table.setSecondary(stickClass: nil, handler: { _ in })
        spy.rangeQueries = 0
        table.updateStickAfterScroll(false)
        XCTAssertEqual(spy.rangeQueries, 0)
    }

    func testVisibleRangesMatchOriginalFormulaAcrossInsetsResizeAndRemoval() {
        for flipped in [false, true] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 400), styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let table = TableView(frame: window.contentView!.bounds, isFlipped: flipped)
            window.contentView!.addSubview(table)
            for index in 0..<60 { _ = table.addItem(item: TableRowItem(.zero, stableId: index)) }
            for height in [CGFloat(400), 200] {
                table.setFrameSize(NSSize(width: 320, height: height))
                for top in [CGFloat(0), 30] {
                    table.contentInsets.top = top
                    for offset in [CGFloat(0), 1, 59, 500, 3000] {
                        table.contentView.scroll(to: NSPoint(x: 0, y: offset))
                        table.layoutSubtreeIfNeeded()
                        for inset in [CGFloat(0), 20, -10] {
                            var rect = NSRect(x: 0, y: table.documentOffset.y, width: table.tableView.realVisibleRect.width, height: table.tableView.realVisibleRect.height).insetBy(dx: 0, dy: -inset)
                            if inset == 0, top > 0 { rect.size.height -= top }
                            XCTAssertEqual(table.visibleRows(inset), table.tableView.rows(in: rect))
                        }
                    }
                }
            }
            table.removeAll()
            XCTAssertEqual(table.visibleRows().length, 0)
            window.close()
        }
    }

    func testCoalescedScrollDeliversFinalPositionAndCallbacksCanChangeRows() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 400), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let table = TableView(frame: window.contentView!.bounds)
        window.contentView!.addSubview(table)
        for index in 0..<60 { _ = table.addItem(item: TableRowItem(.zero, stableId: index)) }
        table.layoutSubtreeIfNeeded()
        var seen: [NSRange] = []
        table.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false) { position in
            seen.append(position.visibleRows)
        })
        table.needUpdateVisibleAfterScroll = true
        for offset in [100, 200, 900] { table.contentView.scroll(to: NSPoint(x: 0, y: offset)) }
        let delivered = expectation(description: "Final scroll delivery")
        DispatchQueue.main.async { delivered.fulfill() }
        wait(for: [delivered], timeout: 2)
        XCTAssertFalse(seen.isEmpty)
        XCTAssertEqual(seen.last, table.visibleRows())
        table.addScroll(listener: TableScrollListener { _ in table.removeAll() })
        table.contentView.scroll(to: NSPoint(x: 0, y: 1200))
        let removed = expectation(description: "Mutation during delivery")
        DispatchQueue.main.async { removed.fulfill() }
        wait(for: [removed], timeout: 2)
        XCTAssertEqual(table.count, 0)
    }
}
