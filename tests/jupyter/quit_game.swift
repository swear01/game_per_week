import AppKit
import Darwin

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty {
    fputs("usage: quit_game.swift PID...\n", stderr)
    exit(2)
}

// Keep this suffix in sync with GAME_EXECUTABLE_SUFFIX in quit_game.py.
let gameExecutableSuffix = "/Slay the Spire 2/SlayTheSpire2.app/Contents/MacOS/Slay the Spire 2"
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
    guard application.executableURL?.path.hasSuffix(gameExecutableSuffix) == true else {
        fputs("pid \(pidValue): not a Slay the Spire 2 process\n", stderr)
        failed = true
        continue
    }
    found = true
    guard !application.isTerminated else {
        fputs("pid \(pidValue): process already exited\n", stderr)
        failed = true
        continue
    }
    if !application.terminate() {
        fputs("pid \(pidValue): terminate request failed\n", stderr)
        failed = true
    }
}

exit(found && !failed ? 0 : 1)
