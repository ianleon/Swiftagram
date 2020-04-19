//
//  WebViewAuthenticator.swift
//  Swiftagram
//
//  Created by Stefano Bertagno on 07/03/2020.
//

#if canImport(WebKit)
import Foundation
import WebKit

import ComposableRequest

/**
   A `class` describing an `Authenticator` relying on a `WKWebView` to fetch cookies.

   ## Usage
   ```swift
   class LoginViewController: UIViewController {
       /// The web view.
       var webView: WKWebView? {
           didSet {
               guard let webView = webView else { return }
               webView.frame = view.frame
               view.addSubview(webView)
           }
       }

       override func viewDidLoad() {
           super.viewDidLoad()

           // Authenticate.
           WebViewAuthenticator { self.webView = $0 }
               .authenticate {
                   switch $0 {
                   case .failure(let error): print(error.localizedDescription)
                   case .success: print("Logged in")
                   }
               }
       }
   }
   ```
*/
@available(iOS 11.0, macOS 10.13, *)
public final class WebViewAuthenticator<Storage: Swiftagram.Storage>: Authenticator {
    /// A `Storage` instance used to store `Secret`s.
    public internal(set) var storage: Storage
    /// A block outputing a configured `WKWebView`.
    /// A `String` holding a custom user agent to be passed to every request.
    internal var webView: (WKWebView) -> Void

    // MARK: Lifecycle
    /// Init.
    /// - parameters:
    ///     - storage: A concrete `Storage` value.
    ///     - webView: A block outputing a configured `WKWebView`.
    public init(storage: Storage, webView: @escaping (WKWebView) -> Void) {
        self.storage = storage
        self.webView = webView
    }

    /// Set `userAgent`.
    /// - parameter userAgent: A `String` representing a valid user agent.
    /// - warning: This method will be removed in the next major release.
    @available(*, deprecated, message: "custom user agents are no longer supported")
    public func userAgent(_ userAgent: String?) -> WebViewAuthenticator<Storage> { return self }

    // MARK: Authenticator
    /// Return a `Secret` and store it in `storage`.
    /// - parameter onChange: A block providing a `Secret`.
    public func authenticate(_ onChange: @escaping (Result<Secret, Error>) -> Void) {
        // Delete all cookies.
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                                                modifiedSince: .distantPast) { [self] in    // keep `self` alive.
                                                    // Update the process pool.
                                                    let configuration = WKWebViewConfiguration()
                                                    configuration.processPool = WKProcessPool()
                                                    let webView = WebView(frame: .zero, configuration: configuration)
                                                    webView.navigationDelegate = webView
                                                    webView.storage = self.storage
                                                    webView.onChange = onChange
                                                    // Return the web view.
                                                    DispatchQueue.main.async {
                                                        self.webView(webView)
                                                        guard let url = URL(string: "https://www.instagram.com/accounts/login/"),
                                                            let request = Request(url)
                                                                .defaultHeader()
                                                                .header("User-Agent", value: Device.default.browserUserAgent)
                                                                .request() else {
                                                                    return onChange(.failure(AuthenticatorError.invalidURL))
                                                        }
                                                        webView.load(request)
                                                    }
        }
    }
}

/// Extend for `TransientStorage`.
@available(iOS 11.0, macOS 10.13, *)
public extension WebViewAuthenticator where Storage == TransientStorage {
    // MARK: Lifecycle
    /// Init.
    /// - parameter webView: A block outputing a configured `WKWebView`.
    convenience init(webView: @escaping (WKWebView) -> Void) {
        self.init(storage: .init(), webView: webView)
    }
}
#endif