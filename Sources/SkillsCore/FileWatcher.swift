import Foundation

/// File system watcher using FSEvents for detecting changes in skill directories.
public final class FileWatcher {
    private let watchedURLs: [URL]
    private let queue: DispatchQueue
    private var eventStream: FSEventStreamRef?
    public var onChange: (() -> Void)?

    public init(roots: [URL], queue: DispatchQueue = .main) {
        self.watchedURLs = roots
        self.queue = queue
    }

    public func start() {
        let paths = watchedURLs.map { $0.path } as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, _, eventPaths, _, _ in
            guard let info = clientCallBackInfo else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            for path in paths {
                if path.hasSuffix(".md") || path.contains("SKILL") {
                    watcher.onChange?()
                    break
                }
            }
        }

        eventStream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot)
        )

        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    public func stop() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    deinit {
        stop()
    }
}
