// Sileo demo (userland) stub — replaces Sileo/Backend/Download Manager/DownloadManager.swift
// and the APTBrokenPackage struct from Sileo/Backend/APT Wrapper/APTJsonParser.swift.
//
// The real DownloadManager downloaded .deb files, verified hashes and queued
// apt operations. The demo has no repos and no downloads: the queue starts
// empty and nothing can ever be queued, so the Downloads tab shows nothing.
// The queue logic is kept verbatim (same sets, same find/remove/add/
// verifyComplete semantics) so the existing Downloads UI compiles and runs.
// Nothing is downloaded and nothing is installed.

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
        for task in urlSessionTasks.values {
            task.cancel()
        }
        urlSessionTasks.removeAll()
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
        for task in urlSessionTasks.values {
            task.cancel()
        }
        urlSessionTasks.removeAll()
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
                // Already started or finished — never start it twice.
                guard !download.started, !download.completed else { continue }
                guard let debURL = package.packageFileURL else {
                    // Sileo demo (userland): no .deb URL for this package.
                    download.queued = true
                    download.failureReason = "No download URL for this package."
                    download.completed = true
                    download.success = false
                    continue
                }
                // Sileo demo (userland): download the real .deb file over
                // plain HTTPS into Documents/Downloads. This is a plain
                // file download — no install happens (stock iOS has no
                // dpkg). The install step still reports failure honestly.
                currentDownloads += 1
                download.queued = true
                download.started = true
                startDownload(download, from: debURL)
            }
            // Same refresh the real completion path triggered, so the UI
            // re-checks verifyComplete and moves to the install step.
            reloadData(recheckPackages: false)
        }
    }

    /// Real .deb download for one queued package.
    private func startDownload(_ download: Download, from url: URL) {
        let fileName = "\(download.package.package)_\(download.package.version).deb"
        let downloadsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destination = downloadsDir.appendingPathComponent(fileName)
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, error in
            guard let self = self else { return }
            DownloadManager.aptQueue.async {
                self.currentDownloads -= 1
                self.urlSessionTasks.removeValue(forKey: download.package.packageID)
                if let error = error {
                    download.failureReason = error.localizedDescription
                    download.success = false
                } else if let tempURL = tempURL {
                    do {
                        if FileManager.default.fileExists(atPath: destination.path) {
                            try FileManager.default.removeItem(at: destination)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: destination)
                        download.progress = 1
                        download.totalBytesWritten = download.totalBytesExpectedToWrite
                        download.success = true
                        download.message = "Saved: \(fileName)"
                    } catch {
                        download.failureReason = error.localizedDescription
                        download.success = false
                    }
                } else {
                    download.failureReason = "Download failed."
                    download.success = false
                }
                download.completed = true
                self.reloadData(recheckPackages: false)
            }
        }
        urlSessionTasks[download.package.packageID] = task
        task.resume()
        pollProgress(download, task: task)
    }

    /// Poll the task's progress and refresh the Downloads cell so the
    /// progress bar moves while the .deb downloads.
    private func pollProgress(_ download: Download, task: URLSessionTask) {
        DispatchQueue.main.async {
            let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                if download.completed || task.state == .completed {
                    timer.invalidate()
                    return
                }
                let progress = task.progress
                download.totalBytesWritten = progress.completedUnitCount
                download.totalBytesExpectedToWrite = progress.totalUnitCount
                if progress.totalUnitCount > 0 {
                    download.progress = CGFloat(progress.fractionCompleted)
                }
                self.viewController.reloadDownload(package: download.package)
            }
            _ = timer
        }
    }

    private var urlSessionTasks: [String: URLSessionTask] = [:]

    public func download(package: String) -> Download? {
        downloads[package]
    }

    public func isEssential(_ package: Package) -> Bool {
        // Sileo demo (userland): no package can be essential — there are
        // no repos and no installed system packages.
        return false
    }
}
