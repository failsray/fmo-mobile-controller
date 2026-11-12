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
        private var didSelfCheck = false

        // First launch: WebKit can lay the page out against a window
        // that has not settled yet, so the page comes out short — even
        // when the load itself waited for a real size. Returning from
        // the background fixes it, which proves a fresh layout with the
        // settled geometry is fullscreen. So, once, shortly after the
        // first load, measure the page: if the body is shorter than the
        // web view, reload once with the settled geometry.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !didSelfCheck else { return }
            didSelfCheck = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak webView] in
                guard let webView = webView else { return }
                webView.evaluateJavaScript("document.body ? document.body.clientHeight : 0") { result, _ in
                    let bodyH = (result as? NSNumber)?.doubleValue ?? 0
                    let viewH = Double(webView.bounds.height)
                    if viewH > 0 && bodyH > 0 && bodyH < viewH - 20 {
                        webView.reload()
                    }
                }
            }
        }

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
