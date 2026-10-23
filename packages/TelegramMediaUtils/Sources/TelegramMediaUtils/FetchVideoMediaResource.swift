import Cocoa
import TelegramCore
import TGGifConverter
import Postbox
import SwiftSignalKit
import TelegramMediaResources
import ArchiveUtils
import TelegramUtils

public func fetchGifMediaResource(resource: LocalFileGifMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        let queue: Queue = Queue()
        var cancelled: Bool = false
        let exportPath = NSTemporaryDirectory() + "\(resource.randomId).mp4"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resource.path)) {
            queue.async {
                TGGifConverter.convertGif(toMp4: data, exportPath: exportPath, completionHandler: { path in
                    _ = NSTemporaryDirectory() + "\(arc4random()).mp4"
//                    let remuxed = FFMpegRemuxer.remux(path, to: remuxedPath)
//                    if remuxed {
//                        try? FileManager.default.removeItem(atPath: path)
//                        try? FileManager.default.moveItem(atPath: remuxedPath, toPath: path)
//                    }
                    if let path = path {
                        subscriber.putNext(.moveLocalFile(path: path))
                    }
                    subscriber.putCompletion()
                }, errorHandler: {
                    subscriber.putError(.generic)
                }, cancelHandler: { () -> Bool in
                    return cancelled
                })
            }
        }
        
        return ActionDisposable {
            cancelled = true
        }
    }
}


public func fetchMovMediaResource(resource: LocalFileVideoMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    if let rendered = PendingVideoRenders.shared.result(for: resource.path) {
        return rendered
            |> castError(MediaResourceDataFetchError.self)
            |> mapToSignal { success -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> in
                if success {
                    return copyMovMediaResource(resource: resource)
                } else {
                    return .fail(.generic)
                }
            }
    }
    return copyMovMediaResource(resource: resource)
}

private func copyMovMediaResource(resource: LocalFileVideoMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        let exportPath = NSTemporaryDirectory() + "\(resource.randomId).mp4"
        if FileManager.default.fileExists(atPath: exportPath) {
            removeFile(at: exportPath)
        }
        try? FileManager.default.copyItem(atPath: resource.path, toPath: exportPath)
        subscriber.putNext(.moveLocalFile(path: exportPath))
        subscriber.putCompletion()
        return EmptyDisposable
    }
}

public func fetchArchiveMediaResource(resource: LocalFileArchiveMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        let source: ArchiveSource = .resource(resource)
        let disposable = archiver.archive(source, startIfNeeded: true).start(next: { status in
            switch status {
            case let .done(url):
                if resource.path.contains("tg_temp_archive_") {
                    try? FileManager.default.removeItem(atPath: resource.path)
                }
                subscriber.putNext(.moveLocalFile(path: url.path))
                subscriber.putCompletion()
                archiver.remove(source)
            case .fail:
                subscriber.putError(.generic)
                subscriber.putCompletion()
            default:
                break
            }
        }, completed: {
            subscriber.putCompletion()
        })
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
}


public func fetchLottieSoundData(resource: LottieSoundMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        let remuxedPath = NSTemporaryDirectory() + "\(arc4random()).mp4"
        try? resource.data.write(to: URL(fileURLWithPath: remuxedPath))
        subscriber.putNext(.moveLocalFile(path: remuxedPath))
        subscriber.putCompletion()
        
        
        return ActionDisposable {
            
        }
    }
}
