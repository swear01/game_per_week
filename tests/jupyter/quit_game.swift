import AppKit
import Darwin

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty {
    fputs("usage: quit_game.swift PID...\n", stderr)
    exit(2)
}

var found = false
var requested = false
for argument in arguments {
    guard let pidValue = Int32(argument), let application = NSRunningApplication(processIdentifier: pid_t(pidValue)) else {
        continue
    }
    found = true
    requested = application.terminate() || requested
}

exit(found && requested ? 0 : 1)
