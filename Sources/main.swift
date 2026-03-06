import AppKit
import CoreServices

let screenshotDir = (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")
let pasteboard = NSPasteboard.general

func matchesScreenshotPattern(_ filename: String) -> Bool {
    filename.hasPrefix("Screenshot ") && filename.hasSuffix(".png") && filename.contains(" at ")
}

func showNotification(title: String, message: String) {
    let script = """
        display notification "\(message.replacingOccurrences(of: "\"", with: "\\\""))" with title "\(title.replacingOccurrences(of: "\"", with: "\\\""))"
    """
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
}

func copyPathAndNotify(_ path: String) {
    pasteboard.clearContents()
    pasteboard.setString(path, forType: .string)

    let basename = (path as NSString).lastPathComponent
    showNotification(title: "Screenshot", message: "Path copied: \(basename)")
}

var lastEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)

func startWatching() {
    var context = FSEventStreamContext()
    let pathsToWatch = [screenshotDir] as CFArray

    guard let stream = FSEventStreamCreate(
        nil,
        { _, _, numEvents, eventPaths, eventFlags, _ in
            guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
            for i in 0..<numEvents {
                let flags = eventFlags[i]
                guard flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0 else { continue }
                guard flags & UInt32(kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRenamed) != 0 else { continue }

                let path = paths[i]
                let filename = (path as NSString).lastPathComponent
                if matchesScreenshotPattern(filename) && FileManager.default.fileExists(atPath: path) {
                    copyPathAndNotify(path)
                }
            }
        },
        &context,
        pathsToWatch,
        lastEventId,
        0.1,
        UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
    ) else {
        fputs("Error: Failed to create FSEvent stream\n", stderr)
        exit(1)
    }

    FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
    FSEventStreamStart(stream)
    fputs("Watching \(screenshotDir) for screenshots...\n", stderr)
}

signal(SIGINT) { _ in exit(0) }
signal(SIGTERM) { _ in exit(0) }

startWatching()
RunLoop.main.run()
