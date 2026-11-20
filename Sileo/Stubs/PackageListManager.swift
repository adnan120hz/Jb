// Sileo demo (userland) — PackageListManager wired to real repo data.
//
// The demo fetches real repo Packages files (see RepoManager) and lists
// them here. No dpkg status file exists on stock iOS, so installedPackages
// stays empty and "Installed" is honestly empty; available updates are
// therefore always []. Listing, search, categories (Tweaks, …) and
// newest-version lookups all run on the real parsed packages.

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
        RepoManager.shared.repoList.flatMap { $0.packageArray }
    }

    private init() {}

    public func initWait() {
        // Sileo demo (userland): nothing to wait for; return immediately.
    }

    public func repoInstallChange() {
        // Sileo demo (userland): no installed packages to re-check.
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
        let (control, tags) = packageEnum
        guard let identifier = control["package"], !identifier.isEmpty,
              let version = control["version"], !version.isEmpty else { return nil }
        let package = Package(package: identifier, version: version)
        package.packageID = identifier
        package.name = control["name"] ?? identifier
        package.section = control["section"]
        package.rawSection = control["section"]
        package.architecture = control["architecture"]
        package.packageDescription = control["description"]?.components(separatedBy: "\n").first
        if let depiction = control["depiction"], let url = URL(string: depiction) {
            package.depiction = url
        }
        if let depiction = control["sileodepiction"], let url = URL(string: depiction) {
            package.nativeDepiction = url
        }
        if let icon = control["icon"], let url = URL(string: icon) {
            package.icon = url
        }
        if let author = control["author"] {
            package.author = Maintainer(string: author)
        }
        if let maintainer = control["maintainer"] {
            package.maintainer = Maintainer(string: maintainer)
        }
        package.filename = control["filename"]
        package.size = control["size"]
        package.essential = control["essential"]
        package.commercial = tags.contains(.commercial)
        if let installedSize = control["installed-size"].flatMap(Int.init) {
            package.installedSize = installedSize
        }
        package.tags = tags
        package.rawControl = control
        return package
    }

    public func packageList(identifier: String = "", search: String? = nil, sortPackages sort: Bool = false, repoContext: Repo? = nil, lookupTable: [String: [Package]]? = nil, packagePrepend: [Package]? = nil) -> [Package] {
        var packages: [Package]
        switch identifier {
        case "--installed", "--contextInstalled":
            packages = packagePrepend ?? Array(installedPackages.values)
        case "--wishlist":
            let ids = WishListManager.shared.wishlist
            packages = self.packages(identifiers: ids, sorted: false, repoContext: repoContext)
        case let id where id.hasPrefix("category:"):
            let wanted = String(id.dropFirst("category:".count))
            let base = repoContext?.packageArray ?? allPackagesArray
            packages = base.filter { Self.humanReadableCategory($0.section) == wanted }
        default:
            packages = repoContext?.packageArray ?? allPackagesArray
        }

        if let search = search, !search.isEmpty {
            let needle = search.lowercased()
            packages = packages.filter { package in
                let haystacks = [package.name, package.package, package.packageDescription]
                return haystacks.contains { $0?.lowercased().contains(needle) == true }
            }
        }

        if sort {
            packages = sortPackages(packages: packages, search: search)
        }
        return packages
    }

    public func sortPackages(packages: [Package], search: String?) -> [Package] {
        packages.sorted(by: { ($0.name ?? $0.packageID).lowercased() < ($1.name ?? $1.packageID).lowercased() })
    }

    public func newestPackage(identifier: String, repoContext: Repo?, packages: [Package]? = nil) -> Package? {
        let candidates = (packages ?? repoContext?.packageArray ?? allPackagesArray)
            .filter { $0.packageID == identifier }
        var newest: Package?
        for candidate in candidates {
            if let current = newest {
                if DpkgWrapper.isVersion(candidate.version, greaterThan: current.version) {
                    newest = candidate
                }
            } else {
                newest = candidate
            }
        }
        return newest
    }

    public func installedPackage(identifier: String) -> Package? {
        // Sileo demo (userland): nothing is installed on stock iOS.
        return installedPackages[identifier]
    }

    public func package(url: URL) -> Package? {
        // Sileo demo (userland): a .deb opened in Sileo has no backend to
        // read it, so the AppDelegate "Bad Deb" path is taken honestly.
        return nil
    }

    public func packages(identifiers: [String], sorted: Bool, repoContext: Repo? = nil, packages: [Package]? = nil) -> [Package] {
        let base = packages ?? repoContext?.packageArray ?? allPackagesArray
        var found: [Package] = []
        for identifier in identifiers {
            if let package = base.first(where: { $0.packageID == identifier }) {
                found.append(package)
            }
        }
        if sorted {
            found = sortPackages(packages: found, search: nil)
        }
        return found
    }

    public func package(identifier: String, version: String, packages: [Package]? = nil) -> Package? {
        let base = packages ?? allPackagesArray
        return base.first { $0.packageID == identifier && $0.version == version }
    }

    public func upgradeAll() {
        // Sileo demo (userland): nothing to upgrade.
    }

    public func upgradeAll(completion: (() -> Void)?) {
        // Sileo demo (userland): nothing to upgrade.
        completion?()
    }
}
