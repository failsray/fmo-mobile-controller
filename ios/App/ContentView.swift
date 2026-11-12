import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        WebView()
            .ignoresSafeArea()
            .background(Color.black)
    }
}

struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // Let the page start audio playback without an extra tap.
        config.mediaTypesRequiringUserActionForPlayback = []
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black

        // Don't load here: the view still has its pre-layout (near-zero)
        // frame at this point, and WebKit would measure viewport units
        // against it, so the first launch is not fullscreen.
        // The page loads from updateUIView once the view has its real
        // size, with a delayed retry below as a safety net.
        scheduleLoadIfNeeded(for: webView, coordinator: context.coordinator)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        loadIfReady(uiView, coordinator: context.coordinator)
    }

    /// Loads the page the first time the web view has a real size.
    private func loadIfReady(_ webView: WKWebView, coordinator: Coordinator, force: Bool = false) {
        guard !coordinator.didLoad else { return }
        guard force || (webView.bounds.width > 0 && webView.bounds.height > 0) else { return }
        coordinator.didLoad = true
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    /// Safety net: if updateUIView never sees a real size (it normally
    /// does), keep retrying briefly, then load anyway rather than
    /// showing a blank screen.
    private func scheduleLoadIfNeeded(for webView: WKWebView, coordinator: Coordinator, attempt: Int = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard !coordinator.didLoad else { return }
            if webView.bounds.height > 0 {
                self.loadIfReady(webView, coordinator: coordinator)
            } else if attempt >= 10 {
                self.loadIfReady(webView, coordinator: coordinator, force: true)
            } else {
                self.scheduleLoadIfNeeded(for: webView, coordinator: coordinator, attempt: attempt + 1)
            }
        }
    }

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var didLoad = false

        // Open external links (for example the GitHub credit link) in
        // Safari instead of inside the controller.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            return nil
        }
    }
}
