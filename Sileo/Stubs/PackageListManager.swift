// Sileo demo (userland) stub — replaces Sileo/Backend/Package Manager/PackageListManager.swift
//
// The real PackageListManager read the dpkg status file and repo Packages
// files. The demo has no installed packages and no repos, so every lookup
// returns nil/[] and initWait returns immediately (the real one waited on a
// semaphore and fatalErrored on the main thread — the demo must do neither).

import Foundation
import UIKit

final class PackageListManager {

    static let reloadNotification = Notification.Name("SileoPackageCacheReloaded")
    static let installChange = Notification.Name("SileoInstallChanged")
    static let stateChange = Notification.Name("SileoStateChanged")
    static let prefsNotification = Notification.Name("SileoPackagePrefsChanged")

    static let shared = PackageListManager()

    private(set) var installedPackages: [String: Package] = [:] {
        didSet {
            NotificationCenter.default.post(name: RepoManager.progressNotification, object: installedPackages.count)
        }
    }

    public var localPackages = [String: Package]()

    public var isLoaded = false

    public var allPackagesArray: [Package] {
        // Sileo demo (userland): no packages exist anywhere.
        return []
    }

    private init() {}

    public func initWait() {
        // Sileo demo (userland): nothing to wait for; return immediately.
    }

    public func repoInstallChange() {
        // Sileo demo (userland): no repos exist.
    }

    public func installChange() {
        installedPackages = [:]
        repoInstallChange()
    }

    public func availableUpdates() -> [(Package, Package?)] {
        // Verbatim logic: with no installed packages and newestPackage
        // always nil, this returns [].
        var updatesAvailable: [(Package, Package?)] = []
        for package in installedPackages.values {
            guard let latestPackage = self.newestPackage(identifier: package.packageID, repoContext: nil) else {
                continue
            }
            if latestPackage.version != package.version {
                if DpkgWrapper.isVersion(latestPackage.version, greaterThan: package.version) {
                    updatesAvailable.append((latestPackage, package))
                }
            }
        }
        return updatesAvailable
    }

    public class func humanReadableCategory(_ rawCategory: String?) -> String {
        let category = rawCategory ?? ""
        if category.isEmpty {
            return String(localizationKey: "No_Category", type: .categories)
        }
        return String(localizationKey: category, type: .categories)
    }

    class func package(packageEnum: ([String: String], PackageTags)) -> Package? {
        // Sileo demo (userland): no package data exists to build from.
        return nil
    }

    public func packageList(identifier: String = "", search: String? = nil, sortPackages sort: Bool = false, repoContext: Repo? = nil, lookupTable: [String: [Package]]? = nil, packagePrepend: [Package]? = nil) -> [Package] {
        // Sileo demo (userland): no packages exist to list.
        return []
    }

    public func sortPackages(packages: [Package], search: String?) -> [Package] {
        return packages
    }

    public func newestPackage(identifier: String, repoContext: Repo?, packages: [Package]? = nil) -> Package? {
        return nil
    }

    public func installedPackage(identifier: String) -> Package? {
        return nil
    }

    public func package(url: URL) -> Package? {
        // Sileo demo (userland): a .deb opened in Sileo has no backend to
        // read it, so the AppDelegate "Bad Deb" path is taken honestly.
        return nil
    }

    public func packages(identifiers: [String], sorted: Bool, repoContext: Repo? = nil, packages: [Package]? = nil) -> [Package] {
        return []
    }

    public func package(identifier: String, version: String, packages: [Package]? = nil) -> Package? {
        return nil
    }

    public func upgradeAll() {
        // Sileo demo (userland): nothing to upgrade.
    }

    public func upgradeAll(completion: (() -> Void)?) {
        // Sileo demo (userland): nothing to upgrade.
        completion?()
    }
}
