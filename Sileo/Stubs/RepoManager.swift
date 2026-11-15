// Sileo demo (userland) stub — replaces Sileo/Backend/Repo Manager/RepoManager.swift
//
// The real RepoManager fetched repo Release/Packages files, parsed them and
// kept a live repo list. The demo has no repos: repoList is always empty,
// every lookup returns nil/false/[], and refresh reports "no update" honestly
// (completion(false, "")). Importing a sources file is accepted and ignored —
// nothing is added, because there is no backend to add it to.

import Foundation
import UIKit

final class RepoManager {

    static let progressNotification = Notification.Name("SileoRepoManagerProgress")

    static let shared = RepoManager()

    private(set) var repoList: [Repo] = []

    private init() {}

    public func update(_ repo: Repo) {
        // Sileo demo (userland): no repos exist to update.
    }

    public func update(_ repos: [Repo]) {
        // Sileo demo (userland): no repos exist to update.
    }

    @discardableResult func addRepos(with urls: [URL]) -> [Repo] {
        // Sileo demo (userland): repos cannot be added.
        return []
    }

    public func addDistRepo(url: URL, suites: String, components: String) -> Repo? {
        // Sileo demo (userland): repos cannot be added.
        return nil
    }

    func remove(repos: [Repo]) {
        // Sileo demo (userland): no repos exist to remove.
    }

    func remove(repo: Repo) {
        // Sileo demo (userland): no repos exist to remove.
    }

    func repo(with url: URL) -> Repo? {
        return nil
    }

    func repo(withSourceFile sourceFile: String) -> Repo? {
        return nil
    }

    func hasRepo(with url: URL) -> Bool {
        return false
    }

    func cacheFile(named name: String, for repo: Repo) -> URL {
        // No repo cache exists; hand back a harmless scratch URL so callers
        // that compare lastPathComponent keep working (repoList is empty,
        // so this is never reached with a real repo).
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    func checkUpdatesInBackground() {
        // Sileo demo (userland): nothing to check.
    }

    func update(force: Bool, forceReload: Bool, isBackground: Bool, repos: [Repo] = RepoManager.shared.repoList, completion: @escaping (Bool, NSAttributedString) -> Void) {
        // Sileo demo (userland): no refresh was performed.
        DispatchQueue.main.async {
            completion(false, NSAttributedString(string: ""))
        }
    }

    public func parseListFile(at url: URL, isImporting: Bool = false) {
        // Sileo demo (userland): importing a sources list adds nothing.
    }

    public func parsePlainTextFile(at url: URL) {
        // Sileo demo (userland): importing a sources list adds nothing.
    }

    public func parseSourcesFile(at url: URL) {
        // Sileo demo (userland): importing a sources list adds nothing.
    }
}
