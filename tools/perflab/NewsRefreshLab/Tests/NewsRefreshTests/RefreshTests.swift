import AppKit
import TGUIKit
import XCTest
@testable import NewsRefreshViews

final class RefreshTests: XCTestCase {
    func fixture() -> (NSWindow, NewsListView, NewsRefreshDropView, NewsPullToRefresh) {
        initializeNewsRefreshLab()
        let window = NSWindow(contentRect: NSMakeRect(0, 0, 360, 400), styleMask: [.borderless], backing: .buffered, defer: false)
        let list = NewsListView(frame: NSMakeRect(0, 0, 360, 400))
        window.contentView = list
        list.topInset = 56
        list.layoutSubtreeIfNeeded()
        for id in 0..<15 {
            _ = list.tableView.addItem(item: TableRowItem(NSMakeSize(360, 60), stableId: id))
        }
        let drop = NewsRefreshDropView(frame: .zero)
        let controller = NewsPullToRefresh(dropView: drop)
        controller.canPull = { _ in true }
        controller.attach(list, baseInset: 56)
        labSetDocumentOffset(list.tableView, -56)
        return (window, list, drop, controller)
    }

    func pull(_ gap: CGFloat, list: NewsListView, controller: NewsPullToRefresh) {
        labSetDocumentOffset(list.tableView, -56 - gap)
        controller.scrolled(list)
    }

    func arm(_ list: NewsListView) {
        NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: list.tableView)
    }

    func progressRing(_ drop: NewsRefreshDropView) -> CAShapeLayer {
        let ringView = drop.subviews[1]
        return ringView.layer!.sublayers!.compactMap { $0 as? CAShapeLayer }.last!
    }

    func testPullProgressHasExplicitFillAnimation() {
        let (window, list, drop, _) = fixture()
        list.setRefreshOverlay(drop)
        drop.showPull(NewsRefreshPresentation(gap: NewsRefreshPresentation.activationDistance / 2))
        let ring = progressRing(drop)
        let animation = ring.animation(forKey: "strokeEnd") as? CABasicAnimation
        XCTAssertNotNil(animation)
        XCTAssertEqual(animation?.fromValue as? NSNumber, 0)
        XCTAssertEqual(animation?.toValue as? NSNumber, 0.5)
        XCTAssertEqual(animation?.duration, 0.12)
        XCTAssertEqual(ring.strokeEnd, 0.5)
        withExtendedLifetime(window) {}
    }

    func testUnchangedProgressDoesNotRestartFill() {
        let (window, list, drop, _) = fixture()
        list.setRefreshOverlay(drop)
        drop.showPull(NewsRefreshPresentation(gap: NewsRefreshPresentation.activationDistance / 2))
        let ring = progressRing(drop)
        let animation = ring.animation(forKey: "strokeEnd")!
        animation.setValue("existing", forKey: "labIdentity")
        ring.add(animation, forKey: "strokeEnd")
        drop.showPull(NewsRefreshPresentation(gap: NewsRefreshPresentation.activationDistance / 2))
        XCTAssertEqual(ring.animation(forKey: "strokeEnd")?.value(forKey: "labIdentity") as? String, "existing")
        withExtendedLifetime(window) {}
    }

    func testProgressRetargetsFromVisibleValueWhenPullReverses() {
        let (window, list, drop, _) = fixture()
        list.setRefreshOverlay(drop)
        drop.showPull(NewsRefreshPresentation(gap: 0))
        window.orderFront(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.04))
        drop.showPull(NewsRefreshPresentation(gap: 16))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let ring = progressRing(drop)
        let visible = ring.presentation()!.strokeEnd
        XCTAssertGreaterThan(visible, 0)
        XCTAssertLessThan(visible, ring.strokeEnd)
        drop.showPull(NewsRefreshPresentation(gap: 4))
        let animation = ring.animation(forKey: "strokeEnd") as! CABasicAnimation
        XCTAssertEqual((animation.fromValue as! NSNumber).doubleValue, Double(visible), accuracy: 0.04)
        XCTAssertEqual((animation.toValue as! NSNumber).doubleValue, 4.0 / Double(NewsRefreshPresentation.activationDistance), accuracy: 0.001)
        window.orderOut(nil)
        withExtendedLifetime(window) {}
    }

    func testLoadingWaitsForRingFillBeforeBurstWithoutDelayingRefresh() {
        let (window, list, drop, controller) = fixture()
        var requests = 0
        controller.refresh = { _ in requests += 1 }
        arm(list)
        let before = CACurrentMediaTime()
        pull(NewsRefreshPresentation.activationDistance, list: list, controller: controller)
        XCTAssertEqual(requests, 1)
        let ring = progressRing(drop)
        XCTAssertNotNil(ring.animation(forKey: "strokeEnd"))
        let fade = ring.animation(forKey: "opacity")!
        XCTAssertGreaterThanOrEqual(fade.beginTime, before + 0.12)
        XCTAssertEqual(fade.fillMode, .both)
        XCTAssertEqual(ring.strokeEnd, 1)
        withExtendedLifetime(window) {}
    }

    func testResetCancelsProgressAndBurstAnimations() {
        let (window, list, drop, _) = fixture()
        list.setRefreshOverlay(drop)
        drop.showPull(NewsRefreshPresentation(gap: NewsRefreshPresentation.activationDistance))
        drop.beginLoading()
        drop.reset()
        let ring = progressRing(drop)
        XCTAssertNil(ring.animationKeys())
        XCTAssertEqual(ring.strokeEnd, 0)
        XCTAssertEqual(ring.opacity, 1)
        XCTAssertTrue(drop.isHidden)
        withExtendedLifetime(window) {}
    }

    func testRevealIsBoundedMonotonicAndFullAtActivation() {
        var previous = NewsRefreshPresentation(gap: -20)
        XCTAssertEqual(previous.opacity, 0)
        for step in 0...1000 {
            let value = NewsRefreshPresentation(gap: CGFloat(step) / 20)
            XCTAssertGreaterThanOrEqual(value.progress, previous.progress)
            XCTAssertGreaterThanOrEqual(value.scale, previous.scale)
            XCTAssertGreaterThanOrEqual(value.opacity, previous.opacity)
            XCTAssertLessThanOrEqual(value.scale, 1)
            XCTAssertLessThanOrEqual(value.opacity, 1)
            previous = value
        }
        let ready = NewsRefreshPresentation(gap: NewsRefreshPresentation.activationDistance)
        XCTAssertEqual(ready.progress, 1)
        XCTAssertEqual(ready.scale, 1)
        XCTAssertEqual(ready.opacity, 1)
        XCTAssertGreaterThan(NewsRefreshPresentation(gap: 5).scale * NewsRefreshPresentation.diameter, 40)
    }

    func testOverlayKeepsFullBoundsAndCenterThroughoutPullAndLoading() {
        let (window, list, drop, controller) = fixture()
        arm(list)
        let tableFrame = list.tableView.contentView.frame
        for gap: CGFloat in [1, 5, 9, NewsRefreshPresentation.activationDistance - 0.1, NewsRefreshPresentation.activationDistance] {
            pull(gap, list: list, controller: controller)
            XCTAssertEqual(drop.frame.size, NSMakeSize(44, 44))
            XCTAssertEqual(drop.frame.midX, list.bounds.midX, accuracy: 0.5)
            XCTAssertEqual(drop.frame.minY, 64)
            XCTAssertEqual(list.tableView.contentView.frame, tableFrame)
        }
        XCTAssertTrue(controller.phase == .loading)
        withExtendedLifetime(window) {}
    }

    func testRefreshFiresOnceAtEasyThreshold() {
        let (window, list, _, controller) = fixture()
        var count = 0
        controller.refresh = { _ in count += 1 }
        arm(list)
        pull(NewsRefreshPresentation.activationDistance - 0.1, list: list, controller: controller)
        XCTAssertEqual(count, 0)
        pull(NewsRefreshPresentation.activationDistance, list: list, controller: controller)
        pull(40, list: list, controller: controller)
        pull(0, list: list, controller: controller)
        XCTAssertEqual(count, 1)
        XCTAssertTrue(controller.holds(list.tableView))
        withExtendedLifetime(window) {}
    }

    func testMomentumDoesNotTriggerRefresh() {
        let (window, list, _, controller) = fixture()
        var count = 0
        controller.refresh = { _ in count += 1 }
        arm(list)
        pull(5, list: list, controller: controller)
        NotificationCenter.default.post(name: NSScrollView.didEndLiveScrollNotification, object: list.tableView)
        pull(30, list: list, controller: controller)
        XCTAssertEqual(count, 0)
        withExtendedLifetime(window) {}
    }

    func testStartingInMiddleOfFeedDoesNotArmRefresh() {
        let (window, list, drop, controller) = fixture()
        labSetDocumentOffset(list.tableView, 100)
        arm(list)
        pull(30, list: list, controller: controller)
        XCTAssertTrue(controller.phase == .idle)
        XCTAssertTrue(drop.isHidden)
        withExtendedLifetime(window) {}
    }

    func testCancelledPullRestoresNewPostsPillAndStopsIcon() {
        let (window, list, drop, controller) = fixture()
        list.installPill(action: {})
        list.updatePill(title: "↑ 171 new", animated: false)
        arm(list)
        pull(9, list: list, controller: controller)
        XCTAssertFalse(list.pillView!.userInteractionEnabled)
        XCTAssertEqual(list.pillView!.layer!.opacity, 0)
        XCTAssertTrue(drop.superview === list)
        XCTAssertTrue(list.subviews.last === drop)
        pull(0, list: list, controller: controller)
        XCTAssertNil(drop.superview)
        XCTAssertTrue(drop.isHidden)
        XCTAssertTrue(list.pillView!.userInteractionEnabled)
        XCTAssertEqual(list.pillView!.layer!.opacity, 1)
        withExtendedLifetime(window) {}
    }

    func testPillUpdatesStayHiddenUnderRefreshOverlay() {
        let (window, list, drop, _) = fixture()
        list.installPill(action: {})
        list.setRefreshOverlay(drop)
        list.updatePill(title: "↑ 171 new", animated: false)
        XCTAssertFalse(list.pillView!.userInteractionEnabled)
        XCTAssertEqual(list.pillView!.layer!.opacity, 0)
        list.updatePill(title: nil, animated: false)
        list.setRefreshOverlay(nil)
        XCTAssertFalse(list.pillView!.userInteractionEnabled)
        XCTAssertEqual(list.pillView!.layer!.opacity, 0)
        withExtendedLifetime(window) {}
    }

    func testResizingKeepsOverlayCenteredAboveList() {
        let (window, list, drop, _) = fixture()
        list.setRefreshOverlay(drop)
        list.frame.size.width = 500
        list.layout()
        XCTAssertEqual(drop.frame.midX, 250, accuracy: 0.5)
        XCTAssertEqual(drop.frame.minY, 64)
        XCTAssertEqual(drop.frame.width, 44)
        withExtendedLifetime(window) {}
    }

    func testOverlayIsMouseTransparent() {
        let (window, list, drop, _) = fixture()
        list.setRefreshOverlay(drop)
        drop.showPull(NewsRefreshPresentation(gap: NewsRefreshPresentation.activationDistance))
        XCTAssertNil(drop.hitTest(NSPoint(x: 22, y: 22)))
        withExtendedLifetime(window) {}
    }

    func testUnrelatedListScrollDoesNotDismissActivePull() {
        let (window, list, drop, controller) = fixture()
        let other = NewsListView(frame: list.frame)
        controller.attach(other, baseInset: 56)
        arm(list)
        pull(9, list: list, controller: controller)
        controller.scrolled(other)
        XCTAssertTrue(drop.superview === list)
        XCTAssertFalse(drop.isHidden)
        withExtendedLifetime(window) {}
    }

    func testUnavailableRefreshDoesNotCoverTheNewPostsPill() {
        let (window, list, drop, controller) = fixture()
        list.installPill(action: {})
        list.updatePill(title: "↑ 171 new", animated: false)
        controller.canPull = { _ in false }
        arm(list)
        pull(30, list: list, controller: controller)
        XCTAssertTrue(controller.phase == .idle)
        XCTAssertNil(drop.superview)
        XCTAssertTrue(list.pillView!.userInteractionEnabled)
        withExtendedLifetime(window) {}
    }

    func testOverscrollDuringLoadingDoesNotShiftTheOverlayOrList() {
        let (window, list, drop, controller) = fixture()
        arm(list)
        pull(NewsRefreshPresentation.activationDistance, list: list, controller: controller)
        let overlayFrame = drop.frame
        let clipFrame = list.tableView.contentView.frame
        for gap: CGFloat in [60, 120, 10, 0] {
            pull(gap, list: list, controller: controller)
            XCTAssertEqual(drop.frame, overlayFrame)
            XCTAssertEqual(list.tableView.contentView.frame, clipFrame)
        }
        withExtendedLifetime(window) {}
    }

    func testCompletionReleasesPendingUpdatesAndRestoresPill() {
        let (window, list, drop, controller) = fixture()
        list.installPill(action: {})
        list.updatePill(title: "↑ 171 new", animated: false)
        let finished = expectation(description: "refresh finished")
        controller.impact = { table in
            XCTAssertFalse(controller.holds(table))
            finished.fulfill()
        }
        arm(list)
        pull(NewsRefreshPresentation.activationDistance, list: list, controller: controller)
        controller.startedAt = CACurrentMediaTime() - 2
        controller.checkLoading()
        wait(for: [finished], timeout: 2)
        XCTAssertTrue(controller.phase == .idle)
        XCTAssertNil(drop.superview)
        XCTAssertTrue(drop.isHidden)
        XCTAssertTrue(list.pillView!.userInteractionEnabled)
        controller.impact = { _ in }
        withExtendedLifetime(window) {}
    }
}
