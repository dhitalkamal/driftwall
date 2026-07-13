import AppKit

// entry point. top-level code in main.swift runs on the main actor, matching the
// main-actor isolation of the app delegate and adapters.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
