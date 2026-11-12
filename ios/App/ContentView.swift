import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        WebViewController()
            .ignoresSafeArea()
            .background(Color.black)
            .preferredColorScheme(.dark)
    }
}

struct WebViewController: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> WebViewControllerImpl {
        let vc = WebViewControllerImpl(coordinator: context.coordinator)
        context.coordinator.viewController = vc
        return vc
    }

    func updateUIViewController(_ uiViewController: WebViewControllerImpl, context: Context) {}

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        weak var viewController: WebViewControllerImpl?

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

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            viewController?.applyPageHeight()
        }
    }
}

class WebViewControllerImpl: UIViewController {
    let coordinator: WebViewController.Coordinator
    var webView: WKWebView!
    private var didLoadPage = false

    init(coordinator: WebViewController.Coordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // Let the page start audio playback without an extra tap.
        config.mediaTypesRequiringUserActionForPlayback = []
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.uiDelegate = coordinator
        webView.navigationDelegate = coordinator
        webView.scrollView.bounces = false
        // Root cause of the first-launch short page (WebKit bug 210009):
        // with viewport-fit=cover, WKWebView reports the viewport height
        // as the window height minus the safe area insets, so a page
        // using height:100% renders short and leaves a black band.
        // .never stops the scroll view from applying safe area insets,
        // so the viewport equals the web view bounds.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        view.addSubview(webView)

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            didLoadPage = true
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutWebView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        layoutWebView()
        applyPageHeight()
    }

    override var prefersStatusBarHidden: Bool { false }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    /// Keep the web view below the status bar and flush with the
    /// bottom edge, whatever SwiftUI first proposes for our frame.
    /// Using the live safe area insets makes this self-correcting:
    /// if our own view is already inset, the inset inside it is 0.
    private func layoutWebView() {
        guard let webView = webView else { return }
        let top = view.safeAreaInsets.top
        let frame = CGRect(
            x: 0,
            y: top,
            width: view.bounds.width,
            height: view.bounds.height - top
        )
        if webView.frame != frame {
            webView.frame = frame
            applyPageHeight()
        }
    }

    /// Pin the page root to the web view's real height in CSS px.
    /// The page uses height:100%, which resolves against whatever
    /// viewport WebKit first computed; on cold launch that can be
    /// the safe-area height, so set it from the native side.
    func applyPageHeight() {
        guard didLoadPage else { return }
        let h = webView.bounds.height
        guard h > 0 else { return }
        let js = "document.documentElement.style.height='\(Int(h))px';document.body.style.height='\(Int(h))px';"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}
