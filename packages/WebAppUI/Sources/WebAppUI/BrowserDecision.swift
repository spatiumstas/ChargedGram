import Foundation

final class BrowserDecision {
    private var resolved = false
    private var dismissalScheduled = false

    func resolve(_ action: () -> Void) {
        guard !resolved else { return }
        resolved = true
        action()
    }

    func dismissed() {
        guard !dismissalScheduled else { return }
        dismissalScheduled = true
        DispatchQueue.main.async {
            self.resolved = true
        }
    }
}
