
import Foundation
import UIKit
import KeychainAccess

public func UsingOAuth2(settings: OAuth2Settings, errorHandler: ((error: NSError?) -> Void)?, performWithToken: (token: String) -> Void) {
    OAuth2Client(oauth2Settings: settings).retrieveAuthToken { (authToken, error) -> Void in
        guard let authToken = authToken where !authToken.isEmpty else {
            var userInfo : [String : AnyObject] = [
                NSLocalizedDescriptionKey: "No token received",
                NSLocalizedFailureReasonErrorKey: "No token received"
            ]

            if let underlyingError = error {
                userInfo[NSUnderlyingErrorKey] = underlyingError
            }

            errorHandler?(error: NSError(domain: "OAuth2Client", code: 1, userInfo: userInfo))
            return
        }

        performWithToken(token: authToken)
    }
}

public func OAuth2ClearTokensFromKeychain(settings: OAuth2Settings) {
    let keychain = Keychain(service: settings.baseURL)
    keychain[kOAuth2AccessTokenService] = nil
    keychain[kOAuth2RefreshTokenService] = nil
}
