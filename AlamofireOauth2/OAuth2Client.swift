
import Foundation
import UIKit
import Alamofire
import KeychainAccess

let kOAuth2AccessTokenService = "OAuth2AccessToken"
let kOAuth2RefreshTokenService = "OAuth2RefreshToken"
let kOAuth2ExpiresInService = "OAuth2ExpiresIn"
let kOAuth2CreationDateService = "OAuth2CreationDate"

public class OAuth2Client : NSObject {

    var oauth2Settings: OAuth2Settings
    var sourceViewController: UIViewController?
    let keychain: Keychain

    public init(oauth2Settings: OAuth2Settings) {
        self.oauth2Settings = oauth2Settings
        self.keychain = Keychain(service: oauth2Settings.baseURL)
    }

    public func retrieveAuthToken(tokenHandler: ((accessToken: String?, error: NSError?) -> Void)) -> Void {

        // We found a token in the keychain, we need to check if it is not expired
        if let accessToken = keychainAccessToken {
            if tokenIsExpired,
                let refreshToken = keychainRefreshToken {
                    self.refreshToken(refreshToken as String, newToken: tokenHandler)
                    return
            } else {
                tokenHandler(accessToken: accessToken, error: nil)
                return
            }
        }

        // First, let's retrieve the autorization_code by login the user in.
        retrieveAuthorizationCode { [oauth2Settings = self.oauth2Settings] (authorizationCode, error) -> Void in
            guard let authorizationCode = authorizationCode else {
                var userInfo : [String : AnyObject] = [
                    NSLocalizedDescriptionKey: "No authorization code received",
                    NSLocalizedFailureReasonErrorKey: "No authorization code received",
                ]

                if let underlyingError = error {
                    userInfo[NSUnderlyingErrorKey] = underlyingError
                }

                tokenHandler(accessToken: nil, error: NSError(domain: "OAuth2Client", code: 3, userInfo: userInfo))
                return
            }

            // We have the authorization_code, we now need to exchange it for the accessToken by doing a POST request
            Alamofire
                .request(.POST,
                    oauth2Settings.tokenURL,
                    parameters: [
                        "client_id": oauth2Settings.clientID,
                        "grant_type": "authorization_code",
                        "redirect_uri": oauth2Settings.redirectURL,
                        "code": authorizationCode
                    ],
                    encoding: Alamofire.ParameterEncoding.URL,
                    headers: [
                        "Authorization": "Basic " + "\(oauth2Settings.clientID):\(oauth2Settings.clientSecret)".dataUsingEncoding(NSUTF8StringEncoding)!.base64EncodedStringWithOptions([])
                    ])
                .responseJSON { [unowned self] (response) -> Void in
                    switch response.result {
                    case .Success(let json):
                        self.postRequestHandler(json, error: nil, tokenHandler: tokenHandler)
                    case .Failure(let error):
                        self.postRequestHandler(nil, error: error, tokenHandler: tokenHandler)
                    }
                }
        }
    }

    // MARK: - Private helper methods

    private var keychainAccessToken : String? {
        get {
            return keychain[kOAuth2AccessTokenService]
        }
        set {
            keychain[kOAuth2AccessTokenService] = newValue
            keychain[kOAuth2CreationDateService] = String(format: "%f", NSDate().timeIntervalSince1970)
        }
    }

    private var tokenIsExpired : Bool {
        var isTokenExpired: Bool = false

        if let expiresInValue = keychainTokenExpiration {
                isTokenExpired = true

                if let creationDateString = keychain[kOAuth2CreationDateService],
                    let creationDate = Double(creationDateString) where NSDate().timeIntervalSince1970 < creationDate + expiresInValue {
                    isTokenExpired = false
                }
        }

        return isTokenExpired
    }

    private var keychainTokenExpiration : Double? {
        get {
            guard let stringValue = keychain[kOAuth2ExpiresInService] else {
                return nil
            }

            return Double(stringValue)
        }
        set {
            if let newValue = newValue {
                keychain[kOAuth2ExpiresInService] = "\(newValue)"
            } else {
                keychain[kOAuth2ExpiresInService] = nil
            }
        }
    }

    private var keychainRefreshToken : String? {
        get {
            return keychain[kOAuth2RefreshTokenService]
        }
        set {
            return keychain[kOAuth2RefreshTokenService] = newValue
        }
    }

    private class func topViewController(base: UIViewController? = UIApplication.sharedApplication().keyWindow?.rootViewController) -> UIViewController? {

        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }

        if let tab = base as? UITabBarController {
            let moreNavigationController = tab.moreNavigationController

            if let top = moreNavigationController.topViewController where top.view.window != nil {
                return topViewController(top)
            } else if let selected = tab.selectedViewController {
                return topViewController(selected)
            }
        }

        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }

        return base
    }

    private var activeController : UIViewController {
        if self.sourceViewController == nil {
            self.sourceViewController = OAuth2Client.topViewController()
        }
        if self.sourceViewController != nil {
            return self.sourceViewController!
        }
        print("WARNING: You should have an active UIViewController! ")
        return UIViewController()
    }

    private func postRequestHandler(jsonResponse: AnyObject?, error: NSError?, tokenHandler: ((accessToken: String?, error: NSError?) -> Void)) -> Void {
        var accessToken : String? = nil

        if let jsonResponse = jsonResponse {
            do {
                accessToken = try retrieveAccessTokenFromJSONResponse(jsonResponse)
            } catch let error as NSError {
                tokenHandler(accessToken: nil, error: error)
                return
            }
        }

        tokenHandler(accessToken: accessToken, error: error)
    }

    private func retrieveAuthorizationCode(codeHandler: ((authorizationCode: String?, error: NSError?) -> Void)) -> Void{

        func success(code: String) -> Void {
            activeController.dismissViewControllerAnimated(true, completion: nil)
            codeHandler(authorizationCode: code, error: nil)
        }

        func failure(error: NSError) -> Void {
            activeController.dismissViewControllerAnimated(true, completion: nil)
            codeHandler(authorizationCode: nil, error: error)
        }

        let authenticationViewController = AuthenticationViewController(oauth2Settings: oauth2Settings, successCallback: success, failureCallback: failure)
        let navigationController = UINavigationController(rootViewController: authenticationViewController)

        activeController.presentViewController(navigationController, animated: true, completion: nil)
    }


    // Request a new access token with our refresh token
    private func refreshToken(refreshToken: String, newToken: ((accessToken:String?, error: NSError?) -> Void)) -> Void {

        print("Need to refresh the token with refreshToken : " + refreshToken)

        let url:String = self.oauth2Settings.tokenURL

        let parameters : [String : String] = [
            "client_id" : oauth2Settings.clientID,
            "grant_type" : "refresh_token",
            "client_secret" : oauth2Settings.clientSecret,
            "redirect_uri" : oauth2Settings.redirectURL,
            "refresh_token" : refreshToken
        ]

        Alamofire
            .request(.POST, url, parameters: parameters, encoding: Alamofire.ParameterEncoding.URL)
            .responseJSON { (response) -> Void in
                switch response.result {
                case .Success(let json):
                    self.postRequestHandler(json, error: nil, tokenHandler: newToken)
                case .Failure(let error):
                    self.postRequestHandler(nil, error: error, tokenHandler: newToken)
                }
        }
    }

    // Extract the accessToken from the JSON response that the authentication server returned
    private func retrieveAccessTokenFromJSONResponse(jsonResponse: AnyObject) throws -> String? {

        var result : String? = nil

        if let jsonResult = jsonResponse as? NSDictionary {

            if let error = jsonResult["error"] as? NSString,
                let errorDescription = jsonResult["error_description"] as? NSString {

                throw NSError(domain: "OAuth2Client", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: errorDescription,
                    NSLocalizedFailureReasonErrorKey: error
                ])
            }

            // Store the required info for future token refresh in the Keychain.
            if let accessToken = jsonResult["access_token"] as? NSString {
                result = accessToken as String
                keychainAccessToken = accessToken as String
            }

            if let refreshToken = jsonResult["refresh_token"] as? NSString {
                keychainRefreshToken = refreshToken as String
            }

            if let expiresIn = jsonResult["expires_in"] as? NSNumber {
                keychainTokenExpiration = Double(expiresIn)
            }
        }

        return result
    }


}
