import Cocoa

// App entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Hide dock icon — we're a utility panel, not a regular app
app.setActivationPolicy(.accessory)

app.run()
