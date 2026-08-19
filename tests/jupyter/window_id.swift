import Cocoa

let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
for window in windows {
    let name = window[kCGWindowName as String] as? String ?? ""
    if name == "Slay the Spire 2" {
        if let id = window[kCGWindowNumber as String] as? Int {
            print(id)
            exit(0)
        }
    }
}
for window in windows {
    let owner = (window[kCGWindowOwnerName as String] as? String ?? "").lowercased()
    if owner.contains("slay the spire 2") {
        if let id = window[kCGWindowNumber as String] as? Int {
            print(id)
            exit(0)
        }
    }
}
exit(1)
