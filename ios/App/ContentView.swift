import SwiftUI
import WebKit
import AVFoundation

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
    private var audioObservers: [NSObjectProtocol] = []

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
        // Audio fix (build 15): Web Audio API is muted by the silent
        // switch and in the background on iOS 16 (WebKit bugs 237322
        // and 251532). A silent looping <audio> element opens the
        // media channel so the radio plays through the switch and
        // keeps the media-playback assertion alive in the background;
        // navigator.audioSession covers iOS 17+. The page itself
        // (index.html) is untouched.
        config.userContentController.addUserScript(
            WKUserScript(source: Self.audioFixScript,
                         injectionTime: .atDocumentEnd,
                         forMainFrameOnly: true)
        )

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

        // Keep the audio session in playback mode when the app returns
        // to the foreground and after an interruption (for example a
        // phone call) ends, so the radio keeps playing through the
        // silent switch and in the background.
        audioObservers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { _ in Self.configureAudioSession() })
        audioObservers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { note in
            guard let info = note.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                  type == .ended else { return }
            Self.configureAudioSession()
        })
    }

    deinit {
        for observer in audioObservers {
            NotificationCenter.default.removeObserver(observer)
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

    /// Re-activate the playback audio session (same setup as App.swift).
    static func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session re-activation failed: \(error)")
        }
    }

    /// JS injected into the page (build 15). See the comment at the
    /// user-script registration in viewDidLoad.
    static let audioFixScript = """
    (function() {
      try { if (navigator.audioSession) { navigator.audioSession.type = 'playback'; } } catch (e) {}
      var el = document.createElement('audio');
      el.src = 'data:audio/wav;base64,UklGRmQGAABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAAZGF0YUAGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      el.loop = true;
      el.volume = 0;
      el.setAttribute('playsinline', '');
      el.style.display = 'none';
      document.documentElement.appendChild(el);
      function start() { try { var p = el.play(); if (p && p.catch) { p.catch(function(){}); } } catch (e) {} }
      function unlockPlayer() { try { if (typeof player !== 'undefined' && player && player.unlock) { player.unlock(); } } catch (e) {} }
      start();
      document.addEventListener('pointerdown', function() { start(); unlockPlayer(); });
      document.addEventListener('visibilitychange', function() {
        if (!document.hidden) {
          try { if (navigator.audioSession) { navigator.audioSession.type = 'playback'; } } catch (e) {}
          start();
          unlockPlayer();
        }
      });
      window.addEventListener('pageshow', function() { start(); unlockPlayer(); });
    })();
    """
}
