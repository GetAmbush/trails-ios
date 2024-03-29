import UIKit
import WebKit

import Security

import Foundation

public class DropboxAccessToken : CustomStringConvertible {
    var accessToken: String
    var uid: String

    init(accessToken: String, uid: String) {
        self.accessToken = accessToken
        self.uid = uid
    }

    public var description : String {
        return self.accessToken
    }
}

/// A failed authorization.
/// See RFC6749 4.2.2.1
///
/// - `UnauthorizedClient` - The client is not authorized to request an access token using this method.
/// - `AccessDenied` -  The resource owner or authorization server denied the request.
/// - `UnsupportedResponseType` - The authorization server does not support obtaining an access token using this method.
/// - `InvalidScope` - The requested scope is invalid, unknown, or malformed.
/// - `ServerError` - The authorization server encountered an unexpected condition that prevented it from fulfilling the request.
/// - `TemporarilyUnavailable` - The authorization server is currently unable to handle the request due to a temporary overloading or maintenance of the server.
/// - `Unknown` - Some other error (outside of the OAuth2 specification)
public enum OAuth2Error {
    case UnauthorizedClient
    case AccessDenied
    case UnsupportedResponseType
    case InvalidScope
    case ServerError
    case TemporarilyUnavailable
    case Unknown

    init(errorCode: String) {
        switch errorCode {
        case "unauthorized_client": self = .UnauthorizedClient
        case "access_denied": self = .AccessDenied
        case "unsupported_response_type": self = .UnsupportedResponseType
        case "invalid_scope": self = .InvalidScope
        case "server_error": self = .ServerError
        case "temporarily_unavailable": self = .TemporarilyUnavailable
        default: self = .Unknown
        }
    }
}

private let kDBLinkNonce = "dropbox.sync.nonce"

/// The result of an authorization attempt.
///
/// - `Success` - The authorization succeeded. Includes a `DropboxAccessToken`.
/// - `Error` - The authorization failed. Includes an `OAuth2Error` and a descriptive message.
public enum DropboxAuthResult {
    case Success(DropboxAccessToken)
    case Error(OAuth2Error, String)
}

private class Keychain {
    class func set(key: String, value: String) -> Bool {
        if let data = value.dataUsingEncoding(NSUTF8StringEncoding) {
            return set(key, value: data)
        } else {
            return false
        }
    }

    class func set(key: String, value: NSData) -> Bool {
        let query : CFDictionaryRef = [
            (      kSecClass as String): kSecClassGenericPassword,
            (kSecAttrAccount as String): key,
            (  kSecValueData as String): value
        ]

        SecItemDelete(query)

        return SecItemAdd(query, nil) == noErr
    }

    class func getAsData(key: String) -> NSData? {
        let query : CFDictionaryRef = [
            (      kSecClass as String): kSecClassGenericPassword,
            (kSecAttrAccount as String): key,
            ( kSecReturnData as String): kCFBooleanTrue,
            ( kSecMatchLimit as String): kSecMatchLimitOne
        ]

        var dataResult : AnyObject?
        let status = withUnsafeMutablePointer(&dataResult) { (ptr) in
            SecItemCopyMatching(query, UnsafeMutablePointer(ptr))
        }

        if status == noErr {
            return dataResult as? NSData
        }

        return nil
    }

    class func getAll() -> [String] {
        let query : CFDictionaryRef = [
            (            kSecClass as String): kSecClassGenericPassword,
            ( kSecReturnAttributes as String): kCFBooleanTrue,
            (       kSecMatchLimit as String): kSecMatchLimitAll
        ]

        var dataResult : AnyObject?
        let status = withUnsafeMutablePointer(&dataResult) { (ptr) in
            SecItemCopyMatching(query, UnsafeMutablePointer(ptr))
        }

        if status == noErr {
            let results = dataResult as? [[String : AnyObject]] ?? []
            return results.map { d in d["acct"] as! String }

        }
        return []
    }



    class func get(key: String) -> String? {
        if let data = getAsData(key) {
            return NSString(data: data, encoding: NSUTF8StringEncoding) as? String
        } else {
            return nil
        }
    }

    class func delete(key: String) -> Bool {
        let query : CFDictionaryRef = [
            (kSecClass as String) : kSecClassGenericPassword,
            (kSecAttrAccount as String): key
        ]

        return SecItemDelete(query) == noErr
    }

    class func clear() -> Bool {
        let query : CFDictionaryRef = [
            (kSecClass as String) : kSecClassGenericPassword,
        ]

        return SecItemDelete(query) == noErr
    }
}
/// Manages access token storage and authentication
///
/// Use the `DropboxAuthManager` to authenticate users through OAuth2, save access tokens, and retrieve access tokens.
public class DropboxAuthManager {

    let appKey : String
    let redirectURL: NSURL
    let dauthRedirectURL: NSURL

    let host: String


    public static var sharedAuthManager : DropboxAuthManager!


    public init(appKey: String, host: String) {
        self.appKey = appKey
        self.host = host
        self.redirectURL = NSURL(string: "db-\(self.appKey)://2/token")!
        self.dauthRedirectURL = NSURL(string: "db-\(self.appKey)://1/connect")!
    }

    convenience public init(appKey: String) {
        self.init(appKey: appKey, host: "www.dropbox.com")
    }

    private func authURL() -> NSURL {
        let components = NSURLComponents()
        components.scheme = "https"
        components.host = self.host
        components.path = "/1/oauth2/authorize"

        components.queryItems = [
            NSURLQueryItem(name: "response_type", value: "token"),
            NSURLQueryItem(name: "client_id", value: self.appKey),
            NSURLQueryItem(name: "redirect_uri", value: self.redirectURL.URLString)
        ]
        return components.URL!
    }

    private func dAuthURL(nonce: String?) -> NSURL {
        let components = NSURLComponents()
        components.scheme =  "dbapi-2"
        components.host = "1"
        components.path = "/connect"

        if let n = nonce {
            let state = "oauth2:\(n)"
            components.queryItems = [
                NSURLQueryItem(name: "k", value: self.appKey),
                NSURLQueryItem(name: "s", value: ""),
                NSURLQueryItem(name: "state", value: state),
            ]
        }
        return components.URL!
    }

    private func canHandleURL(url: NSURL) -> Bool {
        for known in [self.redirectURL, self.dauthRedirectURL] {
            if (url.scheme == known.scheme &&  url.host == known.host && url.path == known.path) {
                return true
            }
        }
        return false
    }

    /// Present the OAuth2 authorization request page by presenting a web view controller modally
    ///
    /// :param: controller
    ///         The controller to present from
    public func authorizeFromController(controller: UIViewController) {
        if UIApplication.sharedApplication().canOpenURL(dAuthURL(nil)) {
            let nonce = NSUUID().UUIDString
            NSUserDefaults.standardUserDefaults().setObject(nonce, forKey: kDBLinkNonce)
            NSUserDefaults.standardUserDefaults().synchronize()

            UIApplication.sharedApplication().openURL(dAuthURL(nonce))
        } else {
            let web = DropboxConnectController(
                URL: self.authURL(),
                tryIntercept: { url in
                    if self.canHandleURL(url) {
                        UIApplication.sharedApplication().openURL(url)
                        return true
                    } else {
                        return false
                    }
                }
            )
            let navigationController = UINavigationController(rootViewController: web)
            controller.presentViewController(navigationController, animated: true, completion: nil)
        }
    }

    private func extractfromDAuthURL(url: NSURL) -> DropboxAuthResult {
        switch url.path ?? "" {
        case "/connect":
            var results = [String: String]()
            let pairs  = url.query?.componentsSeparatedByString("&") ?? []

            for pair in pairs {
                let kv = pair.componentsSeparatedByString("=")
                results.updateValue(kv[1], forKey: kv[0])
            }
            let state = results["state"]?.componentsSeparatedByString("%3A") ?? []

            let nonce = NSUserDefaults.standardUserDefaults().objectForKey(kDBLinkNonce) as? String
            if state.count == 2 && state[0] == "oauth2" && state[1] == nonce! {
                let accessToken = results["oauth_token_secret"]!
                let uid = results["uid"]!
                return .Success(DropboxAccessToken(accessToken: accessToken, uid: uid))
            } else {
                return .Error(.Unknown, "Unable to verify link request")
            }
        default:
            return .Error(.AccessDenied, "User cancelled Dropbox link")
        }
    }

    private func extractFromRedirectURL(url: NSURL) -> DropboxAuthResult {
        var results = [String: String]()
        let pairs  = url.fragment?.componentsSeparatedByString("&") ?? []

        for pair in pairs {
            let kv = pair.componentsSeparatedByString("=")
            results.updateValue(kv[1], forKey: kv[0])
        }

        if let error = results["error"] {
            let desc = results["error_description"]?.stringByReplacingOccurrencesOfString("+", withString: " ").stringByRemovingPercentEncoding
            return .Error(OAuth2Error(errorCode: error), desc ?? "")
        } else {
            let accessToken = results["access_token"]!
            let uid = results["uid"]!
            return .Success(DropboxAccessToken(accessToken: accessToken, uid: uid))
        }
    }

    /// Try to handle a redirect back into the application
    ///
    /// :param: url
    ///         The URL to attempt to handle
    /// :returns: `nil` if SwiftyDropbox cannot handle the redirect URL, otherwise returns the `DropboxAuthResult`.
    public func handleRedirectURL(url: NSURL) -> DropboxAuthResult? {

        if !self.canHandleURL(url) {
            return nil
        }

        let result : DropboxAuthResult
        if url.host == "1" { // dauth
            result = extractfromDAuthURL(url)
        } else {
            result = extractFromRedirectURL(url)
        }

        switch result {
        case .Success(let token):
            Keychain.set(token.uid, value: token.accessToken)
            return result
        default:
            return result
        }
    }

    /// Retrieve all stored access tokens
    ///
    /// :returns: a dictionary mapping users to their access tokens
    public func getAllAccessTokens() -> [String : DropboxAccessToken] {
        let users = Keychain.getAll()
        var ret = [String : DropboxAccessToken]()
        for user in users {
            let isNumeric = Int(user)
            
            if  isNumeric != nil {
                if let accessToken = Keychain.get(user) {
                    ret[user] = DropboxAccessToken(accessToken: accessToken, uid: user)
                }
            }
        }
        return ret
    }

    /// Check if there are any stored access tokens
    ///
    /// :returns: Whether there are stored access tokens
    public func hasStoredAccessTokens() -> Bool {
        return self.getAllAccessTokens().count != 0
    }

    /// Retrieve the access token for a particular user
    ///
    /// :param: user
    ///         The user whose token to retrieve
    /// :returns: An access token if present, otherwise `nil`.
    public func getAccessToken(user: String) -> DropboxAccessToken? {
        if let accessToken = Keychain.get(user) {
            return DropboxAccessToken(accessToken: accessToken, uid: user)
        } else {
            return nil
        }
    }

    /// Delete a specific access token
    ///
    /// :param: token
    ///         The access token to delete
    /// :returns: whether the operation succeeded
    public func clearStoredAccessToken(token: DropboxAccessToken) -> Bool {
        return Keychain.delete(token.uid)
    }

    /// Delete all stored access tokens
    ///
    /// :returns: whether the operation succeeded
    public func clearStoredAccessTokens() -> Bool {
        var success = false
        for dropboxKey in self.getAllAccessTokens().keys {
            success = Keychain.delete(dropboxKey)
        }

        return success
    }

    /// Save an access token
    ///
    /// :param: token
    ///         The access token to save
    /// :returns: whether the operation succeeded
    public func storeAccessToken(token: DropboxAccessToken) -> Bool {
        return Keychain.set(token.uid, value: token.accessToken)
    }

    /// Utility function to return an arbitrary access token
    ///
    /// :returns: the "first" access token found, if any (otherwise `nil`)
    public func getFirstAccessToken() -> DropboxAccessToken? {
        return self.getAllAccessTokens().values.first
    }
}


public class DropboxConnectController : UIViewController, WKNavigationDelegate {
    var webView : WKWebView!

    var onWillDismiss: ((didCancel: Bool) -> Void)?
    var tryIntercept: ((url: NSURL) -> Bool)?

    var cancelButton: UIBarButtonItem?


    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    public init(URL: NSURL, tryIntercept: ((url: NSURL) -> Bool)) {
        super.init(nibName: nil, bundle: nil)
        self.startURL = URL
        self.tryIntercept = tryIntercept
    }
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Link to Dropbox"
        self.webView = WKWebView(frame: self.view.bounds)
        self.view.addSubview(self.webView)

        self.webView.navigationDelegate = self

        self.view.backgroundColor = UIColor.whiteColor()

        self.cancelButton = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancel:")
        self.navigationItem.rightBarButtonItem = self.cancelButton
    }

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if !webView.canGoBack {
            if nil != startURL {
                loadURL(startURL!)
            }
            else {
                webView.loadHTMLString("There is no `startURL`", baseURL: nil)
            }
        }
    }

    public func webView(webView: WKWebView,
        decidePolicyForNavigationAction navigationAction: WKNavigationAction,
        decisionHandler: (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.URL, callback = self.tryIntercept {
                if callback(url: url) {
                    self.dismiss(true)
                    return decisionHandler(.Cancel)
                }
            }
            return decisionHandler(.Allow)
    }

    public var startURL: NSURL? {
        didSet(oldURL) {
            if nil != startURL && nil == oldURL && isViewLoaded() {
                loadURL(startURL!)
            }
        }
    }

    public func loadURL(url: NSURL) {
        webView.loadRequest(NSURLRequest(URL: url))
    }

    func showHideBackButton(show: Bool) {
        navigationItem.leftBarButtonItem = show ? UIBarButtonItem(barButtonSystemItem: .Rewind, target: self, action: "goBack:") : nil
    }

    func goBack(sender: AnyObject?) {
        webView.goBack()
    }

    func cancel(sender: AnyObject?) {
        dismiss(true, animated: (sender != nil))
    }

    func dismiss(animated: Bool) {
        dismiss(false, animated: animated)
    }

    func dismiss(asCancel: Bool, animated: Bool) {
        webView.stopLoading()

        self.onWillDismiss?(didCancel: asCancel)
        presentingViewController?.dismissViewControllerAnimated(animated, completion: nil)
    }

}
