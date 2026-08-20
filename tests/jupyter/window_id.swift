import Cocoa

let gameExecutableMarker = "/Slay the Spire 2/SlayTheSpire2.app/Contents/MacOS/"
let windows: [[String: Any]]
if let windowInfo = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
    windows = windowInfo
} else {
    fputs("error: CGWindowListCopyWindowInfo returned nil (Screen Recording permission missing?)\n", stderr)
    exit(1)
}

func isNormalWindow(_ window: [String: Any]) -> Bool {
    (window[kCGWindowLayer as String] as? Int) == 0
}

func belongsToGame(_ window: [String: Any]) -> Bool {
    let owner = (window[kCGWindowOwnerName as String] as? String ?? "").lowercased()
    if owner.contains("slay the spire 2") {
        return true
    }
    guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int,
          let application = NSRunningApplication(processIdentifier: pid_t(ownerPID)) else {
        return false
    }
    return application.executableURL?.path.contains(gameExecutableMarker) == true
}

for window in windows {
    let name = (window[kCGWindowName as String] as? String ?? "").lowercased()
    if isNormalWindow(window), name == "slay the spire 2", belongsToGame(window),
       let id = window[kCGWindowNumber as String] as? Int {
        print(id)
        exit(0)
    }
}

for window in windows {
    if isNormalWindow(window), belongsToGame(window),
       let id = window[kCGWindowNumber as String] as? Int {
        print(id)
        exit(0)
    }
}

fputs("error: Slay the Spire 2 window not found (is it running and visible, and does the terminal have Screen Recording permission?)\n", stderr)
exit(1)
