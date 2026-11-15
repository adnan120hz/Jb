// Sileo demo (userland) stub — replaces Sileo/Backend/Payment Manager/PaymentManager.swift,
// PaymentProvider.swift and PaymentAuthenticator.swift, plus the
// DownloadOverrideProviding protocol from Sileo/Backend/Download Manager/DownloadOverrideProviding.swift.
//
// The real payment flow talked to repo payment providers over the network.
// The demo has no repos and no providers: getPaymentProvider always reports
// "no payment provider", initiatePurchase always fails honestly, and
// authenticate/handlePayment always complete with that same honest error.
// No purchase can ever be started, and no payment UI can ever proceed past
// the provider lookup.

import Foundation
import UIKit
import AuthenticationServices

protocol DownloadOverrideProviding {
    func downloadURL(for package: Package, from repo: Repo, completionHandler: @escaping (String?, URL?) -> Void) -> Bool

    var hashableObject: AnyHashable { get }
}

enum PaymentStatus: Int {
    case immediateSuccess = 0
    case actionRequred = 1
    case failed = -1
    case cancel = -2
}

class PaymentManager {
    static let shared = PaymentManager()

    var paymentProvidersForURL = [String: PaymentProvider]()
    var paymentProvidersForEndpoint = [String: PaymentProvider]()

    private init() {}

    func getAllPaymentProviders(completion: @escaping (Set<PaymentProvider>) -> Void) {
        // Sileo demo (userland): no repos, so no payment providers exist.
        completion([])
    }

    func getPaymentProvider(for repo: Repo, completion: @escaping (PaymentError?, PaymentProvider?) -> Void) {
        // Sileo demo (userland): no payment provider exists for any repo.
        completion(.noPaymentProvider, nil)
    }

    func getPaymentProvider(for endpoint: String) -> PaymentProvider? {
        return nil
    }
}

class PaymentProvider: Hashable, Equatable, DownloadOverrideProviding {
    let baseURL: URL
    let repoURL: String
    var info: [String: AnyObject]?
    var storedUserInfo: [String: AnyObject]?

    var isInfoFresh = false
    var isUserInfoFresh = false

    static let listUpdateNotificationName = "PaymentProviderListUpdateNotificationName"

    init(baseURL url: URL, repoURL: String) {
        baseURL = url
        self.repoURL = repoURL
        // (The real init loaded a token cache and fetched user info over
        // the network; the demo does neither.)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(baseURL)
    }

    var hashableObject: AnyHashable {
        self as AnyHashable
    }

    var isAuthenticated: Bool {
        // Sileo demo (userland): no provider can ever be authenticated.
        return false
    }

    var authenticationToken: String? {
        return nil
    }

    func fetchInfo(fromCache: Bool, completion: ((PaymentError?, [String: AnyObject]?) -> Void)?) {
        completion?(nil, nil)
    }

    func fetchUserInfo(fromCache: Bool, completion: ((PaymentError?, [String: AnyObject]?) -> Void)?) {
        completion?(nil, nil)
    }

    func signOut(completion: @escaping () -> Void) {
        completion()
    }

    func invalidateSavedToken() {
        // Sileo demo (userland): no token exists to invalidate.
    }

    func getPackageInfo(forIdentifier id: String, completion: @escaping (PaymentError?, PaymentPackageInfo?) -> Void) {
        completion(nil, nil)
    }

    func initiatePurchase(forPackageIdentifier id: String, completion: @escaping (PaymentError?, PaymentStatus, URL?) -> Void) {
        // Sileo demo (userland): purchases cannot be started.
        completion(nil, .failed, nil)
    }

    static func triggerListUpdateNotification() {
        NotificationCenter.default.post(name: Notification.Name(listUpdateNotificationName), object: nil)
    }

    func downloadURL(for package: Package, from repo: Repo, completionHandler: @escaping (String?, URL?) -> Void) -> Bool {
        // Sileo demo (userland): no provider download override exists.
        return false
    }
}

func == (lhs: PaymentProvider, rhs: PaymentProvider) -> Bool {
    lhs.baseURL == rhs.baseURL
}

class PaymentAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = PaymentAuthenticator()
    private var lastWindow: UIWindow?

    private override init() {
        super.init()
    }

    func authenticate(provider: PaymentProvider, window: UIWindow?, completion: ((PaymentError?, Bool) -> Void)?) {
        // Sileo demo (userland): authentication cannot start — there is
        // no payment provider to authenticate against.
        lastWindow = window
        completion?(.noPaymentProvider, false)
    }

    func handlePayment(actionURL url: URL, provider: PaymentProvider, window: UIWindow?, completion: ((PaymentError?, Bool) -> Void)?) {
        // Sileo demo (userland): no payment action can be handled.
        lastWindow = window
        completion?(.noPaymentProvider, false)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return lastWindow ?? UIWindow()
    }
}
