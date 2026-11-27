import Cocoa
import WebKit

/// FMO-X macOS 1.6.6 — WKWebView shell around the same single-file
/// web controller as the iOS and Android apps (index.html).
/// Deployment target macOS 10.15 (Catalina). No code signing.
/// The page is copied from ios/App/Resources/index.html at build time,
/// so the desktop app always ships the current 1.6.6 page.
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(macOS 11.0, *) {
            // Let the page start audio without an extra tap (same as iOS).
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        let prefs = WKPreferences()
        prefs.javaScriptEnabled = true
        config.preferences = prefs

        webView = WKWebView(frame: .zero, configuration: config)
        webView.autoresizingMask = [.width, .height]

        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let w: CGFloat = min(1000, screen.width * 0.85)
        let h: CGFloat = min(700, screen.height * 0.85)
        let rect = NSRect(x: (screen.width - w) / 2, y: (screen.height - h) / 2, width: w, height: h)
        window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "FMO-X"
        window.minSize = NSSize(width: 480, height: 600)
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
