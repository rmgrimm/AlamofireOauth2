#AlamofireOauth2

A Swift implementation of OAuth2 Authorization Code Grant for iOS using Alamofire.

[![Build Status](https://travis-ci.org/rmgrimm/AlamofireOauth2.svg?style=flat)](https://travis-ci.org/rmgrimm/AlamofireOauth2)
[![Issues](https://img.shields.io/github/issues-raw/rmgrimm/AlamofireOauth2.svg?style=flat)](https://github.com/rmgrimm/AlamofireOauth2/issues)
[![Stars](https://img.shields.io/github/stars/rmgrimm/AlamofireOauth2.svg?style=flat)](https://github.com/rmgrimm/AlamofireOauth2/stargazers)

#Intro

This library is heavily inspired by the [SwiftOAuth2 repository from crousselle](https://github.com/crousselle/SwiftOAuth2)

AlamofireOauth2 relies on [Alamofire](https://github.com/Alamofire/Alamofire), and [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)


## Using AlamofireOauth2 in your own App

'AlamofireOauth2' is now available through the dependency manager [CocoaPods](http://cocoapods.org).
You do have to use cocoapods version 0.36. At this moment this can be installed by executing:

```
[sudo] gem install cocoapods
```

If you have installed cocoapods version 0.36 or later, then you can just add AlamofireOauth2 to your workspace by adding the following 2 lines to your Podfile:

```
use_frameworks!
pod "AlamofireOauth2"
```

Version 0.36 of CocoaPods will make a dynamic framework of all the pods that you use. Because of that it's only supported in iOS 8.0 or later. When using a framework, you also have to add an import at the top of your swift file like this:

```
import AlamofireOauth2
```

If you want support for older versions than iOS 8.0, then you can also just copy the AlamofireOauth2 folder containing the 4 classes to your app. besides that you also have to embed the [Alamofire](https://github.com/Alamofire/Alamofire), and [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) libraries


## Building the AlamofireOaut2Test demo

1) Clone the repo to a working directory

2) [CocoaPods](http://cocoapods.org) is used to manage dependencies. Pods are setup easily and are distributed via a ruby gem. Follow the simple instructions on the website to setup. After setup, run the following command from the toplevel directory of AlamofireOauth to download the dependencies for AlamofireOauth:

```sh
pod install
```

3) Open the `AlamofireOauth.xcworkspace` in Xcode and.

4) Create your own clientID and clientSecret at https://developer.wordpress.com/docs/oauth2/

5) set the clientID and clientSecret in the wordpressOauth2Settings object in the ViewController

and you are ready to go!

## How to use the AlamofireOauth2

Below is the sample code for a simple call to the WorPress API while authenticating using OAuth2


```Swift
class ViewController: UIViewController {

    @IBOutlet weak var result: UITextView!

    @IBAction func startWordpressOauth2Test(sender: AnyObject) {
        self.result.text = ""
        UsingOAuth2(wordpressOauth2Settings, errorHandler: { error in
            print("Oauth2 failed")
            }) { token in
                WordPressRequestConvertible.OAuthToken = token
                Alamofire.request(WordPressRequestConvertible.Me())
                    .responseJSON(completionHandler: { (result) -> Void in
                        if let data = result.data {
                            let response = NSString(data: data, encoding: NSUTF8StringEncoding)
                            self.result.text = "\(response)"
                            print("JSON = \(response)")

                        }
                    })
        }
    }
}

// Create your own clientID and clientSecret at https://developer.wordpress.com/docs/oauth2/
let wordpressOauth2Settings = OAuth2Settings(
    baseURL: "https://public-api.wordpress.com/rest/v1",
    authorizeURL: "https://public-api.wordpress.com/oauth2/authorize",
    tokenURL: "https://public-api.wordpress.com/oauth2/token",
    redirectURL: "http://evict.nl",
    clientID: "????????????",
    clientSecret: "????????????",
    scope: ""
)

// Minimal Alamofire implementation. For more info see https://github.com/Alamofire/Alamofire#crud--authorization
public enum WordPressRequestConvertible: URLRequestConvertible {
    static var baseURLString: String? = wordpressOauth2Settings.baseURL
    static var OAuthToken: String?

    case Me()

    public var URLRequest: NSMutableURLRequest { get {
        let URL = NSURL(string: WordPressRequestConvertible.baseURLString!)!
        let mutableURLRequest = NSMutableURLRequest(URL: URL.URLByAppendingPathComponent("/me"))
        mutableURLRequest.HTTPMethod = "GET"

        if let token = WordPressRequestConvertible.OAuthToken {
            mutableURLRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return mutableURLRequest
        }
    }
}
```
## License

AlamofireOauth2 is available under the MIT 3 license. See the LICENSE file for more info.
