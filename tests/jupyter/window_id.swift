import Cocoa

let windows: [[String: Any]]
if let windowInfo = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
    windows = windowInfo
} else {
    fputs("error: CGWindowListCopyWindowInfo returned nil (Screen Recording permission missing?)\n", stderr)
    exit(1)
}

for window in windows {
    let owner = (window[kCGWindowOwnerName as String] as? String ?? "").lowercased()
    if owner.contains("slay the spire 2"), let id = window[kCGWindowNumber as String] as? Int {
        print(id)
        exit(0)
    }
}

for window in windows {
    let name = window[kCGWindowName as String] as? String ?? ""
    if name == "Slay the Spire 2", let id = window[kCGWindowNumber as String] as? Int {
        print(id)
        exit(0)
    }
}

fputs("error: Slay the Spire 2 window not found (is it running and visible, and does the terminal have Screen Recording permission?)\n", stderr)
exit(1)
