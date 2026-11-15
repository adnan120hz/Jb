// Sileo demo (userland) stub — replaces Sileo/Backend/Download Manager/DownloadManager.swift
// and the APTBrokenPackage struct from Sileo/Backend/APT Wrapper/APTJsonParser.swift.
//
// The real DownloadManager downloaded .deb files, verified hashes and queued
// apt operations. The demo has no repos and no downloads: the queue logic is
// kept verbatim (same sets, same find/remove/add/verifyComplete semantics),
// but startMoreDownloads SIMULATES a download completing — it marks the
// queued demo entry success and reloads, so the existing Downloads UI flow
// reaches the install step, which reports failure honestly via APTWrapper
// and offers the neospring respring. No download is ever claimed real and
// no package is ever claimed installed.
//
// The demo queue is seeded at init with ONE entry ("Demo Respring") so the
// Downloads tab has something to show and the respring path is reachable.
// removeAllItems clears it; relaunch re-seeds it.

import Foundation
import UIKit
import Evander

struct APTBrokenPackage: Decodable, Hashable {

    static func == (lhs: APTBrokenPackage, rhs: APTBrokenPackage) -> Bool {
        lhs.packageID == rhs.packageID && lhs.conflictingPackages == rhs.conflictingPackages
    }

    struct ConflictingPackage: Decodable, Hashable {

        // swiftlint:disable nesting
        enum Conflict: String, Decodable {
            case preDepends = "Pre-Depends"
            case recommends = "Recommends"
            case conflicts = "Conflicts"
            case replaces = "Replaces"
            case depends = "Depends"
        }

        // swiftlint:disable nesting
        enum CodingKeys: String, CodingKey {
            case package = "Package"
            case conflict = "Type"
        }

        let package: String
        let conflict: Conflict

        func hash(into hasher: inout Hasher) {
            hasher.combine(package)
            hasher.combine(conflict)
        }

        static func == (lhs: ConflictingPackage, rhs: ConflictingPackage) -> Bool {
            lhs.package == rhs.package && lhs.conflict == rhs.conflict
        }
    }

    let packageID: String
    let conflictingPackages: [ConflictingPackage]

    func hash(into hasher: inout Hasher) {
        hasher.combine(packageID)
        hasher.combine(conflictingPackages)
    }
}

enum DownloadManagerQueue {
    case upgrades
    case installations
    case uninstallations
    case installdeps
    case uninstalldeps
    case none
}

final class DownloadManager {
    static let lockStateChangeNotification = Notification.Name("SileoDownloadManagerLockStateChanged")
    static let aptQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "Sileo.AptQueue", qos: .userInitiated)
        queue.setSpecific(key: DownloadManager.queueKey, value: DownloadManager.queueContext)
        return queue
    }()
    public static let queueKey = DispatchSpecificKey<Int>()
    public static var queueContext = 50

    static let shared = DownloadManager()

    public var lockedForInstallation = false {
        didSet {
            // NotificationCenter.default.post(name: DownloadManager.lockStateChangeNotification, object: nil)
        }
    }
    public var totalProgress = CGFloat(0)

    var upgrades = SafeSet<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var installations = SafeSet<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var uninstallations = SafeSet<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var installdeps = SafeSet<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var uninstalldeps = SafeSet<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var errors = SafeSet<APTBrokenPackage>(queue: aptQueue, key: queueKey, context: queueContext)

    private var currentDownloads = 0
    public var queueStarted = false
    var downloads: [String: Download] = [:]
    var cachedFiles: [URL] = []

    var repoDownloadOverrideProviders: [String: Set<AnyHashable>] = [:]

    var viewController: DownloadsTableViewController

    init() {
        viewController = DownloadsTableViewController(nibName: "DownloadsTableViewController", bundle: nil)
        // Seed the demo queue with one entry so the Downloads tab can show
        // the flow and the respring trigger is reachable. This is demo data
        // only — it is not a real package and is never installed.
        let demoPackage = Package(package: "com.sileo.demo-respring", version: "1.0")
        demoPackage.name = "Demo Respring"
        demoPackage.packageDescription = "Demo queue entry. Confirm runs the demo flow and offers a respring — nothing is installed."
        installations.insert(DownloadPackage(package: demoPackage))
    }

    public func installingPackages() -> Int {
        upgrades.count + installations.count + installdeps.count
    }

    public func uninstallingPackages() -> Int {
        uninstallations.count + uninstalldeps.count
    }

    public func operationCount() -> Int {
        upgrades.count + installations.count + uninstallations.count + installdeps.count + uninstalldeps.count
    }

    public func downloadingPackages() -> Int {
        var downloadsCount = 0
        for keyValue in downloads where keyValue.value.progress < 1 {
            downloadsCount += 1
        }
        return downloadsCount
    }

    public func readyPackages() -> Int {
        var readyCount = 0
        for keyValue in downloads {
            let download = keyValue.value
            if download.progress == 1 && download.success == true {
                readyCount += 1
            }
        }
        return readyCount
    }

    public func verifyComplete() -> Bool {
        let allRawDownloads = upgrades.raw.union(installations.raw).union(installdeps.raw)
        for dlPackage in allRawDownloads {
            guard let download = downloads[dlPackage.package.packageID],
                  download.success else { return false }
        }
        return true
    }

    public func cancelDownloads() {
        for download in downloads.values {
            download.task?.cancel()
            if let backgroundTaskIdentifier = download.backgroundTask {
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            }
        }
        downloads.removeAll()
        currentDownloads = 0
    }

    public func removeAllItems() {
        upgrades.removeAll()
        installdeps.removeAll()
        installations.removeAll()
        uninstalldeps.removeAll()
        uninstallations.removeAll()
        errors.removeAll()
        for download in downloads.values {
            download.task?.cancel()
            if let backgroundTaskIdentifier = download.backgroundTask {
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            }
        }
        downloads.removeAll()
        currentDownloads = 0
        // (The real removeAllItems re-ran checkInstalled() here; the demo
        // has no installed packages, so there is nothing to re-check.)
    }

    public func reloadData(recheckPackages: Bool) {
        reloadData(recheckPackages: recheckPackages, completion: nil)
    }

    public func reloadData(recheckPackages: Bool, completion: (() -> Void)?) {
        DownloadManager.aptQueue.async { [self] in
            // (The real reloadData re-ran recheckTotalOps() here when
            // recheckPackages was true; the demo has no packages to
            // re-check, so that step is skipped.)
            DispatchQueue.main.async {
                self.viewController.reloadData()
                TabBarController.singleton?.updatePopup(completion: completion)
                NotificationCenter.default.post(name: PackageListManager.stateChange, object: nil)
            }
        }
    }

    public func find(package: Package) -> DownloadManagerQueue {
        let downloadPackage = DownloadPackage(package: package)
        if installations.contains(downloadPackage) {
            return .installations
        } else if uninstallations.contains(downloadPackage) {
            return .uninstallations
        } else if upgrades.contains(downloadPackage) {
            return .upgrades
        } else if installdeps.contains(downloadPackage) {
            return .installdeps
        } else if uninstalldeps.contains(downloadPackage) {
            return .uninstalldeps
        }
        return .none
    }

    public func find(package: String) -> DownloadManagerQueue {
        if installations.contains(where: { $0.package.package == package }) {
            return .installations
        } else if uninstallations.contains(where: { $0.package.package == package }) {
            return .uninstallations
        } else if upgrades.contains(where: { $0.package.package == package }) {
            return .upgrades
        } else if installdeps.contains(where: { $0.package.package == package }) {
            return .installdeps
        } else if uninstalldeps.contains(where: { $0.package.package == package }) {
            return .uninstalldeps
        }
        return .none
    }

    public func remove(package: String) {
        installations.remove { $0.package.package == package }
        upgrades.remove { $0.package.package == package }
        installdeps.remove { $0.package.package == package }
        uninstallations.remove { $0.package.package == package }
        uninstalldeps.remove { $0.package.package == package }
    }

    public func add(package: Package, queue: DownloadManagerQueue, approved: Bool = false) {
        let downloadPackage = DownloadPackage(package: package)
        let found = find(package: package.package)
        if found == queue { return }
        remove(downloadPackage: downloadPackage, queue: found)

        switch queue {
        case .none:
            return
        case .installations:
            installations.insert(downloadPackage)
        case .uninstallations:
            if approved == false && isEssential(downloadPackage.package) {
                let message = String(format: String(localizationKey: "Essential_Warning"),
                                     "\n\(downloadPackage.package.name ?? downloadPackage.package.packageID)")
                let alert = UIAlertController(title: String(localizationKey: "Warning"),
                                              message: message,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String(localizationKey: "Cancel"), style: .default, handler: { _ in
                    alert.dismiss(animated: true)
                }))
                alert.addAction(UIAlertAction(title: String(localizationKey: "Dangerous_Repo.Last_Chance.Continue"), style: .destructive, handler: { _ in
                    self.add(package: downloadPackage.package, queue: .uninstallations, approved: true)
                    self.reloadData(recheckPackages: true)
                }))
                TabBarController.singleton?.present(alert, animated: true)
                return
            }
            uninstallations.insert(downloadPackage)
        case .upgrades:
            upgrades.insert(downloadPackage)
        case .installdeps:
            installdeps.insert(downloadPackage)
        case .uninstalldeps:
            uninstalldeps.insert(downloadPackage)
        }
    }

    public func upgradeAll(packages: Set<Package>, _ completion: @escaping () -> ()) {
        Self.aptQueue.async { [self] in
            var packages = packages
            let mapped = upgrades.map { $0.package.package }
            // NOTE: Set has no removeAll(where:) — filter + reassign instead.
            packages = packages.filter { !mapped.contains($0.package) }
            for package in packages {
                let downloadPackage = DownloadPackage(package: package)
                let found = find(package: package.package)
                if found == .upgrades { continue }
                remove(downloadPackage: downloadPackage, queue: found)
                upgrades.insert(downloadPackage)
            }
            completion()
        }
    }

    public func remove(package: Package, queue: DownloadManagerQueue) {
        let downloadPackage = DownloadPackage(package: package)
        remove(downloadPackage: downloadPackage, queue: queue)
    }

    public func remove(downloadPackage: DownloadPackage, queue: DownloadManagerQueue) {
        switch queue {
        case .none:
            return
        case .installations:
            installations.remove(downloadPackage)
        case .uninstallations:
            uninstallations.remove(downloadPackage)
        case .upgrades:
            upgrades.remove(downloadPackage)
        case .installdeps:
            installdeps.remove(downloadPackage)
        case .uninstalldeps:
            uninstalldeps.remove(downloadPackage)
        }
    }

    func startMoreDownloads() {
        DownloadManager.aptQueue.async { [self] in
            // We don't want more than one download at a time
            guard currentDownloads <= 3 else { return }
            // Get a list of downloads that need to take place
            let allRawDownloads = upgrades.raw.union(installations.raw).union(installdeps.raw)
            for dlPackage in allRawDownloads {
                // Get the download object, we don't want to create multiple
                let download: Download
                let package = dlPackage.package
                if let tmp = downloads[package.packageID] {
                    download = tmp
                } else {
                    download = Download(package: package)
                    downloads[package.packageID] = download
                }
                // Sileo demo (userland): there is no .deb to fetch, so the
                // download is SIMULATED as complete. This only lets the
                // existing Downloads UI flow reach the install step, which
                // then reports failure honestly and offers respring.
                // Nothing is downloaded and nothing is installed.
                download.queued = true
                download.progress = 1
                download.success = true
                download.completed = true
            }
            // Same refresh the real completion path triggered, so the UI
            // re-checks verifyComplete and moves to the install step.
            reloadData(recheckPackages: false)
        }
    }

    public func download(package: String) -> Download? {
        downloads[package]
    }

    public func isEssential(_ package: Package) -> Bool {
        // Sileo demo (userland): no package can be essential — there are
        // no repos and no installed system packages.
        return false
    }
}
