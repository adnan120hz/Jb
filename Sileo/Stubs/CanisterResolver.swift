// Sileo demo (userland) stub — replaces Sileo/Backend/Canister Resolver/CanisterResolver.swift
//
// The real CanisterResolver searched api.canister.me and ingested packages
// into it. The demo never contacts Canister: fetch/batchFetch report "no
// change" honestly, ingest/queue are no-ops, and every package lookup
// returns nil. ProvisionalPackage / ProvisionalRepo are copied verbatim
// (they are plain data types the UI renders).

import UIKit
import Evander

final class CanisterResolver {

    public static let nistercanQueue = DispatchQueue(label: "Sileo.NisterCan", qos: .userInteractive)
    public static let shared = CanisterResolver()
    public var packages = SafeArray<ProvisionalPackage>(queue: canisterQueue, key: queueKey, context: queueContext)

    static let canisterQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "Sileo.CanisterQueue", qos: .userInitiated)
        queue.setSpecific(key: CanisterResolver.queueKey, value: CanisterResolver.queueContext)
        return queue
    }()
    public static let queueKey = DispatchSpecificKey<Int>()
    public static var queueContext = 50

    static let refreshList = Notification.Name("Canister.RefreshList")

    private init() {}

    @discardableResult public func fetch(_ query: String, fetch: ((Bool) -> Void)? = nil) -> Bool {
        // Sileo demo (userland): Canister is not contacted; nothing changed.
        fetch?(false)
        return false
    }

    @discardableResult public func batchFetch(_ packages: [String], fetch: ((Bool) -> Void)? = nil) -> Bool {
        // Sileo demo (userland): Canister is not contacted; nothing changed.
        fetch?(false)
        return false
    }

    class public func piracy(_ urls: [URL], response: @escaping (_ safe: [URL], _ piracy: [URL]) -> Void) {
        // Sileo demo (userland): no piracy list is consulted; with no data
        // to judge by, every URL is reported as-is in the safe list.
        response(urls, [])
    }

    public func queuePackage(_ package: Package) {
        // Sileo demo (userland): nothing is queued for Canister.
    }

    public func queueCache() {
        // Sileo demo (userland): nothing is queued for Canister.
    }

    public class func package(_ provisional: ProvisionalPackage) -> Package? {
        // Sileo demo (userland): no Canister package can resolve.
        return nil
    }

    public func package(for bundleID: String) -> Package? {
        // Sileo demo (userland): no Canister package can resolve.
        return nil
    }

    public func ingest(packages: [Package]) {
        // Sileo demo (userland): nothing is sent to Canister.
    }
}

struct ProvisionalPackage: PackageProtocol, Decodable {

    static func ==(lhs: ProvisionalPackage, rhs: ProvisionalPackage) -> Bool {
        lhs.package == rhs.package && lhs.version == rhs.version
    }

    let package: String
    let version: String

    let name: String?
    let maintainer: Maintainer?
    let author: Maintainer?
    let architecture: DPKGArchitecture.Architecture?
    let section: String?
    let description: String?

    let icon: URL?
    let sileoDepiction: URL?
    let header: URL?

    let repository: ProvisionalRepo

    public var defaultIcon: UIImage {
        if let section = section {
            // we have to do this because some repos have various Addons sections
            // ie, Addons (activator), Addons (youtube), etc
            if section.lowercased().contains("addons") {
                return UIImage(named: "Category_addons") ?? UIImage(named: "Category_tweak")!
            } else if section.lowercased().contains("themes") {
                // same case for themes
                return UIImage(named: "Category_themes") ?? UIImage(named: "Category_tweak")!
            }

            return UIImage(named: "Category_\(section.lowercased())") ?? UIImage(named: "Category_tweak")!
        }
        return UIImage(named: "Category_tweak")!
    }

}

struct ProvisionalRepo: Decodable, Equatable, Hashable {

    let uri: URL
    let slug: String
    let tier: Int

    let suite: String
    let isBootstrap: Bool

    static func ==(lhs: ProvisionalRepo, rhs: ProvisionalRepo) -> Bool {
        lhs.slug == rhs.slug
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(slug)
    }
}
