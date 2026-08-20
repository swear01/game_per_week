import AppKit
import Darwin

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty {
    fputs("usage: quit_game.swift PID...\n", stderr)
    exit(2)
}

var found = false
var failed = false
for argument in arguments {
    guard let pidValue = Int32(argument),
          let application = NSRunningApplication(processIdentifier: pid_t(pidValue)) else {
        failed = true
        continue
    }
    guard application.executableURL?.path.contains("/Slay the Spire 2") == true else {
        failed = true
        continue
    }
    found = true
    if !application.terminate() {
        failed = true
    }
}

exit(found && !failed ? 0 : 1)
