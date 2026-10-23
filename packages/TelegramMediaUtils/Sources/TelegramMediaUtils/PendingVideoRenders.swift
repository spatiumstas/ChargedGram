import Foundation
import SwiftSignalKit

public final class PendingVideoRenderInfo {
    public let duration: Double
    public let dimensions: CGSize
    public let hasAudio: Bool
    private let state: Atomic<(frame: Data?, make: (() -> Data?)?)>

    public init(duration: Double, dimensions: CGSize, hasAudio: Bool, frame: @escaping () -> Data?) {
        self.duration = duration
        self.dimensions = dimensions
        self.hasAudio = hasAudio
        self.state = Atomic(value: (frame: nil, make: frame))
    }

    public var frame: Data? {
        let current = state.with { $0 }
        guard let make = current.make else {
            return current.frame
        }
        let frame = make()
        _ = state.swap((frame: frame, make: nil))
        return frame
    }
}

public final class PendingVideoRenders {
    public static let shared = PendingVideoRenders()

    private final class Entry {
        let info: PendingVideoRenderInfo
        let result = Promise<Bool>()
        let disposable = MetaDisposable()

        init(info: PendingVideoRenderInfo) {
            self.info = info
        }
    }

    private let entries = Atomic<[String: Entry]>(value: [:])

    public func add(path: String, info: PendingVideoRenderInfo, render: Signal<Bool, NoError>) {
        let entry = Entry(info: info)
        var previous: Entry?
        _ = entries.modify { current in
            var current = current
            previous = current[path]
            current[path] = entry
            return current
        }
        if let previous = previous {
            previous.disposable.dispose()
            previous.result.set(.single(false))
        }
        entry.disposable.set(render.start(next: { [weak entry] success in
            entry?.result.set(.single(success))
        }, completed: { [weak entry] in
            entry?.disposable.set(nil)
        }))
    }

    public func info(for path: String) -> PendingVideoRenderInfo? {
        return entries.with { $0[path]?.info }
    }

    public func result(for path: String) -> Signal<Bool, NoError>? {
        guard let entry = entries.with({ $0[path] }) else {
            return nil
        }
        return entry.result.get() |> take(1)
    }

    public func cancel(path: String) {
        var removed: Entry?
        _ = entries.modify { current in
            var current = current
            removed = current.removeValue(forKey: path)
            return current
        }
        guard let removed = removed else {
            return
        }
        removed.disposable.dispose()
        removed.result.set(.single(false))
        try? FileManager.default.removeItem(atPath: path)
    }
}
