import AppKit
import Darwin

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty {
    fputs("usage: quit_game.swift PID...\n", stderr)
    exit(2)
}

let gameExecutableMarker = "/Slay the Spire 2/SlayTheSpire2.app/Contents/MacOS/"
var found = false
var failed = false
for argument in arguments {
    guard let pidValue = Int32(argument) else {
        fputs("pid \(argument): invalid process id\n", stderr)
        failed = true
        continue
    }
    guard let application = NSRunningApplication(processIdentifier: pid_t(pidValue)) else {
        fputs("pid \(pidValue): process not found\n", stderr)
        failed = true
        continue
    }
    guard application.executableURL?.path.contains(gameExecutableMarker) == true else {
        fputs("pid \(pidValue): not a Slay the Spire 2 process\n", stderr)
        failed = true
        continue
    }
    found = true
    if !application.terminate() {
        fputs("pid \(pidValue): terminate request failed\n", stderr)
        failed = true
    }
}

exit(found && !failed ? 0 : 1)
