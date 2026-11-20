// Sileo demo (userland) — real repo metadata fetcher.
//
// The demo fetches real repo Release/Packages files over plain HTTPS and
// parses them into Package objects, so Sources/Featured/Search show real
// packages and the Tweaks category can be browsed. Pure network + parsing:
// no privilege, no jailbreak code, no dpkg, no apt. Installed packages stay
// empty (nothing can be installed on stock iOS) and the install step still
// reports failure honestly — see APTWrapper. GET queues a package and
// downloads its .deb file; see DownloadManager.

import Foundation
import Compression
import UIKit

final class RepoManager {

    static let progressNotification = Notification.Name("SileoRepoManagerProgress")

    static let shared = RepoManager()

    private static let savedSourcesKey = "SileoDemoSourceEntries"
    private static let defaultSourceEntry = "deb https://havoc.app/ ./"

    private(set) var repoList: [Repo] = []

    private let workQueue = DispatchQueue(label: "Sileo.DemoRepoFetch", qos: .userInitiated)
    private let session = URLSession(configuration: .default)

    init() {
        let entries = UserDefaults.standard.stringArray(forKey: Self.savedSourcesKey)
            ?? [Self.defaultSourceEntry]
        for entry in entries {
            if let repo = Self.repo(fromDebLine: entry) {
                repoList.append(repo)
            }
        }
    }

    // MARK: - Sources persistence

    private func saveSources() {
        let entries = repoList.map { $0.rawEntry }
        UserDefaults.standard.set(entries, forKey: Self.savedSourcesKey)
    }

    /// "deb <url> <suite> <components...>" -> Repo (layout already known).
    private static func repo(fromDebLine line: String) -> Repo? {
        let parts = line.split(separator: " ").map(String.init)
        guard parts.count >= 3, parts[0] == "deb",
              let url = URL(string: parts[1]), url.host != nil else { return nil }
        let repo = Repo()
        repo.rawURL = parts[1]
        repo.suite = parts[2]
        repo.components = Array(parts.dropFirst(3))
        repo.rawEntry = line
        repo.entryFile = Self.cacheDirectory(for: repo).appendingPathComponent("sileo.sources").path
        return repo
    }

    private static func cacheDirectory(for repo: Repo) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SileoDemoRepos", isDirectory: true)
        let host = URL(string: repo.rawURL)?.host ?? "unknown"
        let safe = host.replacingOccurrences(of: ".", with: "_")
            + "_" + String(abs(repo.rawURL.hashValue % 100000))
        return base.appendingPathComponent(safe, isDirectory: true)
    }

    // MARK: - Repo list

    public func update(_ repo: Repo) {
        update(force: false, forceReload: true, isBackground: false, repos: [repo], completion: { _, _ in })
    }

    public func update(_ repos: [Repo]) {
        update(force: false, forceReload: true, isBackground: false, repos: repos, completion: { _, _ in })
    }

    /// Create Repo objects for the given URLs (bare repo URLs, as the
    /// Sources UI passes them). Layout (flat vs dists) is probed during
    /// update(); the repos are returned immediately so the UI can show
    /// them while the fetch runs in the background.
    @discardableResult func addRepos(with urls: [URL]) -> [Repo] {
        var added: [Repo] = []
        for url in urls {
            var raw = url.absoluteString
            while raw.hasSuffix("/") { raw.removeLast() }
            guard URL(string: raw)?.host != nil else { continue }
            if repoList.contains(where: { $0.rawURL == raw }) { continue }
            let repo = Repo()
            repo.rawURL = raw
            repo.suite = ""
            repo.components = []
            repo.rawEntry = "deb \(raw) ./"
            repo.entryFile = Self.cacheDirectory(for: repo).appendingPathComponent("sileo.sources").path
            repoList.append(repo)
            added.append(repo)
        }
        if !added.isEmpty { saveSources() }
        return added
    }

    public func addDistRepo(url: URL, suites: String, components: String) -> Repo? {
        var raw = url.absoluteString
        while raw.hasSuffix("/") { raw.removeLast() }
        guard URL(string: raw)?.host != nil else { return nil }
        if let existing = repoList.first(where: { $0.rawURL == raw }) { return existing }
        let repo = Repo()
        repo.rawURL = raw
        repo.suite = suites
        repo.components = components.split(separator: " ").map(String.init)
        repo.rawEntry = "deb \(raw) \(suites) \(components)"
        repo.entryFile = Self.cacheDirectory(for: repo).appendingPathComponent("sileo.sources").path
        repoList.append(repo)
        saveSources()
        return repo
    }

    func remove(repos: [Repo]) {
        for repo in repos { remove(repo: repo) }
    }

    func remove(repo: Repo) {
        repoList.removeAll { $0 === repo }
        saveSources()
        NotificationCenter.default.post(name: PackageListManager.reloadNotification, object: nil)
    }

    func repo(with url: URL) -> Repo? {
        repoList.first { $0.rawURL == url.absoluteString || $0.url == url }
    }

    func repo(withSourceFile sourceFile: String) -> Repo? {
        repoList.first { $0.rawEntry == sourceFile }
    }

    func hasRepo(with url: URL) -> Bool {
        repo(with: url) != nil
    }

    func cacheFile(named name: String, for repo: Repo) -> URL {
        let dir = Self.cacheDirectory(for: repo)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }

    func checkUpdatesInBackground() {
        update(force: false, forceReload: false, isBackground: true, repos: repoList, completion: { _, _ in })
    }

    // MARK: - Fetching

    public func update(force: Bool, forceReload: Bool, isBackground: Bool, repos: [Repo] = RepoManager.shared.repoList, completion: @escaping (Bool, NSAttributedString) -> Void) {
        let targets = repos.isEmpty ? repoList : repos
        guard !targets.isEmpty else {
            DispatchQueue.main.async { completion(false, NSAttributedString(string: "")) }
            return
        }
        workQueue.async {
            var errors: [String] = []
            let group = DispatchGroup()
            for repo in targets {
                group.enter()
                self.refresh(repo: repo) { error in
                    if let error = error { errors.append("\(repo.displayURL): \(error)") }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                NotificationCenter.default.post(name: PackageListManager.reloadNotification, object: nil)
                NotificationCenter.default.post(name: PackageListManager.stateChange, object: nil)
                let text = errors.joined(separator: "\n")
                completion(!errors.isEmpty, NSAttributedString(string: text))
            }
        }
    }

    /// Probe layout, fetch Release + Packages, parse into repo.packageDict.
    private func refresh(repo: Repo, completion: @escaping (String?) -> Void) {
        repo.startedRefresh = true
        repo.releaseProgress = 0
        repo.packagesProgress = 0
        probeLayout(repo: repo) { [weak self] layoutError in
            guard let self = self else { return completion("cancelled") }
            if let layoutError = layoutError { return completion(layoutError) }
            self.fetchRelease(repo: repo)
            self.fetchPackages(repo: repo, completion: completion)
        }
    }

    /// Flat repo: <rawURL>/Release exists. Otherwise try
    /// <rawURL>/dists/stable/Release (suite "stable", component "main").
    private func probeLayout(repo: Repo, completion: @escaping (String?) -> Void) {
        if !repo.suite.isEmpty { return completion(nil) }
        guard let base = URL(string: repo.rawURL) else { return completion("bad repo URL") }
        let flatRelease = base.appendingPathComponent("Release")
        fetch(flatRelease) { data, _ in
            if data != nil {
                repo.suite = "./"
                repo.components = []
                repo.rawEntry = "deb \(repo.rawURL) ./"
                self.saveSources()
                return completion(nil)
            }
            let distsRelease = base.appendingPathComponent("dists/stable/Release")
            self.fetch(distsRelease) { data2, _ in
                if data2 != nil {
                    repo.suite = "stable"
                    repo.components = ["main"]
                    repo.rawEntry = "deb \(repo.rawURL) stable main"
                    self.saveSources()
                    return completion(nil)
                }
                completion("no Release file found (not a repo?)")
            }
        }
    }

    private func fetchRelease(repo: Repo) {
        // Release is fetched for the repo name/description; failure is
        // non-fatal (the Packages file is what matters).
        guard let releaseURL = releaseURL(for: repo) else { return }
        fetch(releaseURL) { data, _ in
            guard let data = data,
                  let text = String(data: data, encoding: .utf8),
                  let (dict, _) = try? ControlFileParser.dictionary(controlFile: text, isReleaseFile: true) else { return }
            let name = dict["label"] ?? dict["origin"]
            DispatchQueue.main.async {
                if let name = name, !name.isEmpty { repo.repoName = name }
                if let description = dict["description"] { repo.repoDescription = description }
                repo.releaseProgress = 1
            }
            try? data.write(to: self.cacheFile(named: "Release", for: repo))
        }
    }

    private func releaseURL(for repo: Repo) -> URL? {
        guard let base = URL(string: repo.rawURL) else { return nil }
        if repo.isFlat {
            return base.appendingPathComponent("Release")
        }
        return base.appendingPathComponent("dists").appendingPathComponent(repo.suite).appendingPathComponent("Release")
    }

    private func fetchPackages(repo: Repo, completion: @escaping (String?) -> Void) {
        guard let packagesURL = repo.packagesURL(arch: "iphoneos-arm") else {
            return completion("bad Packages URL")
        }
        fetch(packagesURL) { [weak self] data, _ in
            guard let self = self else { return completion("cancelled") }
            if let data = data {
                self.parsePackages(data, repo: repo, completion: completion)
                return
            }
            // Fall back to the gzipped index.
            let gzURL = packagesURL.appendingPathExtension("gz")
            self.fetch(gzURL) { gzData, _ in
                guard let gzData = gzData,
                      let plain = Self.gunzip(gzData) else {
                    return completion("could not fetch Packages (plain or .gz)")
                }
                self.parsePackages(plain, repo: repo, completion: completion)
            }
        }
    }

    private func parsePackages(_ data: Data, repo: Repo, completion: @escaping (String?) -> Void) {
        try? data.write(to: cacheFile(named: "Packages", for: repo))
        guard let text = String(data: data, encoding: .utf8) ??
                         String(data: data, encoding: .isoLatin1) else {
            return completion("Packages file is not text")
        }
        let entries = ControlFileParser.dictionaries(controlFile: text)
        var dict: [String: Package] = [:]
        dict.reserveCapacity(entries.count)
        for (control, tags) in entries {
            guard let package = Self.package(from: control, tags: tags, repo: repo) else { continue }
            if let existing = dict[package.packageID] {
                existing.addOld(from: package)
            } else {
                dict[package.packageID] = package
            }
        }
        let parsed = dict
        DispatchQueue.main.async {
            repo.packageDict = parsed
            repo.isLoaded = true
            repo.packagesProgress = 1
            repo.startedRefresh = false
            NotificationCenter.default.post(name: RepoManager.progressNotification, object: repo)
            NotificationCenter.default.post(name: PackageListManager.reloadNotification, object: nil)
            completion(nil)
        }
    }

    /// Build a Package from one Packages-file paragraph.
    private static func package(from control: [String: String], tags: PackageTags, repo: Repo) -> Package? {
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
        if let filename = control["filename"] {
            package.filename = filename
            var base = repo.rawURL
            while base.hasSuffix("/") { base.removeLast() }
            package.packageFileURL = URL(string: base + "/" + filename)
        }
        package.size = control["size"]
        package.essential = control["essential"]
        package.commercial = tags.contains(.commercial)
        if let installedSize = control["installed-size"].flatMap(Int.init) {
            package.installedSize = installedSize
        }
        package.tags = tags
        package.rawControl = control
        package.sourceFile = repo.rawEntry
        package.source = URL(string: repo.rawURL)
        return package
    }

    // MARK: - HTTP helpers

    private func fetch(_ url: URL, completion: @escaping (Data?, URLResponse?) -> Void) {
        var request = URLRequest(url: url)
        request.setValue("Sileo/2.5.1 (userland demo)", forHTTPHeaderField: "User-Agent")
        session.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                completion(nil, response)
            } else {
                completion(data, response)
            }
        }.resume()
    }

    /// zlib decompress (Packages.gz). Uses the Compression C API so it
    /// works on the iOS 12 deployment target; no liblzma (missing on
    /// stock iOS — that is what crashed the first userland build).
    private static func gunzip(_ data: Data) -> Data? {
        let srcSize = data.count
        var dstCapacity = max(srcSize * 4, 1 << 20)
        for _ in 0..<4 {
            var dst = Data(count: dstCapacity)
            let decoded = data.withUnsafeBytes { src -> Int in
                dst.withUnsafeMutableBytes { dstPtr -> Int in
                    guard let srcBase = src.baseAddress, let dstBase = dstPtr.baseAddress else { return 0 }
                    return compression_decode_buffer(dstBase.assumingMemoryBound(to: UInt8.self), dstCapacity,
                                                     srcBase.assumingMemoryBound(to: UInt8.self), srcSize,
                                                     nil, COMPRESSION_ZLIB)
                }
            }
            if decoded > 0 {
                dst.count = decoded
                return dst
            }
            dstCapacity *= 4
        }
        return nil
    }

    // MARK: - Sources file import

    public func parseListFile(at url: URL, isImporting: Bool = false) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        parseSourcesText(text)
    }

    public func parsePlainTextFile(at url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        parseSourcesText(text)
    }

    public func parseSourcesFile(at url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        parseSourcesText(text)
    }

    private func parseSourcesText(_ text: String) {
        var urls: [URL] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("deb ") else { continue }
            let parts = trimmed.split(separator: " ").map(String.init)
            guard parts.count >= 2, let url = URL(string: parts[1]) else { continue }
            urls.append(url)
        }
        guard !urls.isEmpty else { return }
        let added = addRepos(with: urls)
        if !added.isEmpty {
            update(force: false, forceReload: true, isBackground: false, repos: added, completion: { _, _ in })
        }
    }
}
