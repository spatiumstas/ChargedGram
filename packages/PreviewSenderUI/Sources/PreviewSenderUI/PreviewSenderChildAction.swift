import Dispatch

final class PreviewSenderChildAction {

    private let isCurrent: () -> Bool
    private var resolved = false
    private var dismissalScheduled = false

    init(isCurrent: @escaping () -> Bool) {
        self.isCurrent = isCurrent
    }

    func resolve(_ action: () -> Void) {
        guard !resolved else { return }
        resolved = true
        guard isCurrent() else { return }
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
