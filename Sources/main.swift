import AppKit
import CoreServices

// MARK: - Globals

var currentMode = "path"
var currentHotkey = "cmd+shift+e"
let recentScreenshotWindow: TimeInterval = 3
var hotkeyModifiers: CGEventFlags = [.maskCommand, .maskShift]
var hotkeyKeyCode: Int64 = 14  // 'e'
var lastScreenshotPath: String?
var lastScreenshotDetectedAt: Date?

let pasteboard = NSPasteboard.general

// MARK: - Screenshot Directory

func getScreenshotDir() -> String {
    if let customPath = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
       !customPath.isEmpty {
        return (customPath as NSString).expandingTildeInPath
    }
    return (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")
}

let screenshotDir = getScreenshotDir()

// MARK: - Configuration

func configDir() -> String {
    (NSHomeDirectory() as NSString).appendingPathComponent(".config/shotpath")
}

func configFilePath() -> String {
    (configDir() as NSString).appendingPathComponent("config.yaml")
}

func loadConfig() {
    guard let contents = try? String(contentsOfFile: configFilePath(), encoding: .utf8) else { return }
    for line in contents.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        let parts = trimmed.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { continue }
        let key = parts[0].trimmingCharacters(in: .whitespaces)
        let value = parts[1].trimmingCharacters(in: .whitespaces)
        switch key {
        case "mode" where value == "path" || value == "image":
            currentMode = value
        case "hotkey" where !value.isEmpty:
            currentHotkey = value
        default: break
        }
    }
}

func saveConfig() {
    let dir = configDir()
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
    let content = """
    # shotpath configuration

    # Mode: "path" copies the file path, "image" copies the image data
    mode: \(currentMode)

    # Global hotkey to toggle modes, or copy the most recent screenshot image in path mode
    # Format: modifier+modifier+key
    # Supported modifiers: cmd, shift, ctrl, option
    hotkey: \(currentHotkey)
    """
    try? content.write(toFile: configFilePath(), atomically: true, encoding: .utf8)
}

// MARK: - Screenshot Pattern

func matchesScreenshotPattern(_ filename: String) -> Bool {
    filename.hasPrefix("Screenshot ") && filename.hasSuffix(".png") && filename.contains(" at ")
}

// MARK: - Notifications

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

// MARK: - Clipboard

func copyPathAndNotify(_ path: String) {
    pasteboard.clearContents()
    pasteboard.setString(path, forType: .string)
    let basename = (path as NSString).lastPathComponent
    showNotification(title: "Screenshot", message: "Path copied: \(basename)")
}

func copyImageAndNotify(_ path: String) {
    guard let image = NSImage(contentsOfFile: path) else {
        copyPathAndNotify(path)
        return
    }
    pasteboard.clearContents()
    pasteboard.writeObjects([image])
    let basename = (path as NSString).lastPathComponent
    showNotification(title: "Screenshot", message: "Image copied: \(basename)")
}

func recentScreenshotPath() -> String? {
    guard let lastScreenshotPath, let lastScreenshotDetectedAt else { return nil }
    guard Date().timeIntervalSince(lastScreenshotDetectedAt) <= recentScreenshotWindow else { return nil }
    guard FileManager.default.fileExists(atPath: lastScreenshotPath) else { return nil }
    return lastScreenshotPath
}

func handleScreenshot(_ path: String) {
    lastScreenshotPath = path
    lastScreenshotDetectedAt = Date()

    if currentMode == "image" {
        copyImageAndNotify(path)
    } else {
        copyPathAndNotify(path)
    }
}

// MARK: - Hotkey

let keyCodeMap: [String: Int64] = [
    "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3,
    "g": 5, "h": 4, "i": 34, "j": 38, "k": 40, "l": 37,
    "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15,
    "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
    "y": 16, "z": 6
]

func parseHotkey(_ hotkey: String) -> Bool {
    let parts = hotkey.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
    var modifiers: CGEventFlags = []
    var key = ""

    for part in parts {
        switch part {
        case "cmd", "command": modifiers.insert(.maskCommand)
        case "shift": modifiers.insert(.maskShift)
        case "ctrl", "control": modifiers.insert(.maskControl)
        case "option", "alt": modifiers.insert(.maskAlternate)
        default: key = part
        }
    }

    guard let code = keyCodeMap[key] else { return false }
    hotkeyModifiers = modifiers
    hotkeyKeyCode = code
    return true
}

func setupHotkey() {
    guard parseHotkey(currentHotkey) else {
        fputs("Warning: Invalid hotkey '\(currentHotkey)', hotkey toggle disabled\n", stderr)
        return
    }

    let eventMask = (1 << CGEventType.keyDown.rawValue)

    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,
        eventsOfInterest: CGEventMask(eventMask),
        callback: { _, _, event, _ -> Unmanaged<CGEvent>? in
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])

            if keyCode == hotkeyKeyCode && flags == hotkeyModifiers {
                DispatchQueue.main.async { toggleMode() }
            }
            return Unmanaged.passUnretained(event)
        },
        userInfo: nil
    ) else {
        fputs("Warning: Could not create event tap for hotkey. Grant Accessibility access in System Settings > Privacy & Security > Accessibility.\n", stderr)
        return
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    fputs("Hotkey '\(currentHotkey)' registered\n", stderr)
}

func toggleMode() {
    if currentMode == "path", let path = recentScreenshotPath() {
        copyImageAndNotify(path)
        fputs("Copied recent screenshot image without changing mode\n", stderr)
        return
    }

    currentMode = (currentMode == "path") ? "image" : "path"
    saveConfig()
    let label = currentMode == "path" ? "Copy Path" : "Copy Image"
    showNotification(title: "shotpath", message: "Mode: \(label)")
    fputs("Mode toggled to: \(currentMode)\n", stderr)
}

// MARK: - File System Watching

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
                    handleScreenshot(path)
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

// MARK: - Main

signal(SIGINT) { _ in exit(0) }
signal(SIGTERM) { _ in exit(0) }

loadConfig()
if !FileManager.default.fileExists(atPath: configFilePath()) {
    saveConfig()
}
fputs("Mode: \(currentMode)\n", stderr)

setupHotkey()
startWatching()
RunLoop.main.run()
