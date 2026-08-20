import Cocoa

let gameExecutableSuffix = "/Slay the Spire 2/SlayTheSpire2.app/Contents/MacOS/Slay the Spire 2"
let windows = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] ?? []

for window in windows {
    guard
        (window[kCGWindowLayer as String] as? Int) == 0,
        (window[kCGWindowOwnerName as String] as? String) == "Slay the Spire 2",
        let pid = window[kCGWindowOwnerPID as String] as? pid_t,
        let application = NSRunningApplication(processIdentifier: pid),
        application.executableURL?.path.hasSuffix(gameExecutableSuffix) == true,
        let windowId = window[kCGWindowNumber as String] as? UInt32
    else {
        continue
    }

    print(windowId)
    exit(0)
}

fputs("game window not found\n", stderr)
exit(1)
