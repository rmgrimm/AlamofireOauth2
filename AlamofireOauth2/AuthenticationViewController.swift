
import Foundation
import UIKit

class AuthenticationViewController : UIViewController, UIWebViewDelegate{

    let expectedState : String = "authDone"

    weak var webView : UIWebView?

    var successCallback : ((code: String)-> Void)?
    var failureCallback : ((error: NSError) -> Void)?

    var isRetrievingAuthCode : Bool = false

    var oauth2Settings : OAuth2Settings!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    convenience init(oauth2Settings: OAuth2Settings, successCallback: ((code: String) -> Void), failureCallback: ((error: NSError) -> Void)) {
        self.init(nibName: nil, bundle: nil)

        self.oauth2Settings = oauth2Settings
        self.successCallback = successCallback
        self.failureCallback = failureCallback
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Login"

        let webView = UIWebView(frame: view.bounds)
        self.webView = webView

        webView.backgroundColor = UIColor.clearColor()
        webView.scalesPageToFit = true
        webView.delegate = self

        view.addSubview(webView)
        view.backgroundColor = UIColor.whiteColor()

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .Plain, target: self, action: Selector("cancelAction"))
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        // TO alter if more parameters needed
        let redirectURI = oauth2Settings.redirectURL.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let url = "\(oauth2Settings.authorizeURL)?response_type=code&client_id=\(oauth2Settings.clientID)&redirect_uri=\(redirectURI)&scope=\(oauth2Settings.scope)&state=\(expectedState)"
        let urlRequest = NSURLRequest(URL: NSURL(string: url)!)

        webView?.loadRequest(urlRequest)
    }

    func cancelAction() {
        dismissViewControllerAnimated(true, completion: nil)
    }

    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {

        let url : NSString = request.URL!.absoluteString

        isRetrievingAuthCode = url.hasPrefix(oauth2Settings.redirectURL)

        if isRetrievingAuthCode {
            guard url.rangeOfString("error").location == NSNotFound else {
                let error: NSError = NSError(domain: "CROAuth2UnknownErrorDomain", code: 0, userInfo: nil)
                failureCallback?(error: error)
                return true
            }

            if let state = extractParameterFromUrl("state", url: url) where state == expectedState,
                let code = extractParameterFromUrl("code", url: url) {
                    successCallback?(code: code)
            }
        }

        return true
    }

    func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        if !isRetrievingAuthCode {
            var userInfo : [String : AnyObject] = [
                NSLocalizedDescriptionKey: "Could not retrieve auth code",
                NSLocalizedFailureReasonErrorKey: "Could not retrieve auth code"
            ]

            if let error = error {
                userInfo[NSUnderlyingErrorKey] = error
            }

            failureCallback?(error: NSError(domain: "OAuth2Client", code: 4, userInfo: userInfo))
        }
    }


    func extractParameterFromUrl(parameterName: String, url: NSString) -> String? {

        guard url.rangeOfString("?").location != NSNotFound else {
            return nil
        }

        let urlString = url.componentsSeparatedByString("?")[1]
        var dict = [String: String]()

        for param in urlString.componentsSeparatedByString("&") {
            var array = param.componentsSeparatedByString("=")

            let name: String = array[0]
            let value: String = array[1]

            dict[name] = value
        }

        if let result = dict[parameterName] {
            return result
        }

        return nil
    }
}


