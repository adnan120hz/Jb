//
//  NewsResolver.swift
//  Sileo
//
//  Created by Amy on 18/04/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import Foundation
import Evander

class NewsResolver {
    
    static let shared = NewsResolver()
    public var articles = [NewsArticle]()
    public var showNews = false
    
    init() {
        self.getArticles()
    }
    
    public func getArticles() {
        if !articles.isEmpty { return }
        // Sileo demo (userland): the Sileo news feed is long dead, so the
        // News tab would stay empty. Bundle a few real jailbreak-community
        // news items the user asked for (Calif glyph grift etc.). These
        // always show; the remote feed is still appended when it returns
        // anything fresh.
        let bundled = Self.bundledArticles()
        articles.append(contentsOf: bundled)
        if !bundled.isEmpty {
            DispatchQueue.main.async {
                self.showNews = true
                NotificationCenter.default.post(name: NewsResolver.ShowNews, object: nil)
            }
        }
        EvanderNetworking.request(url: "https://getsileo.app/api/new.json", type: [String: Any].self) { [weak self] success, _, _, dict in
            guard success,
                  let strong = self,
                  let dict = dict,
                  let articles = dict["articles"] as? [[String: String?]] else {
                    return
            }
            let cutoff = Date(timeIntervalSince1970: Date().timeIntervalSince1970 - 7890000)
            for articleDict in articles {
                if let article = NewsArticle(dict: articleDict),
                   article.date > cutoff,
                   !strong.articles.contains(where: { $0.url == article.url }) {
                    strong.articles.append(article)
                }
            }

            let shouldShow = strong.articles.contains(where: { $0.date > Date(timeIntervalSince1970: Date().timeIntervalSince1970 - 1209600 ) })
            if shouldShow {
                DispatchQueue.main.async {
                    strong.showNews = true
                    NotificationCenter.default.post(name: NewsResolver.ShowNews, object: nil)
                }
            }
        }
    }

    /// Demo news items bundled with the app (real, public stories).
    private static func bundledArticles() -> [NewsArticle] {
        let raw: [[String: String?]] = [
            [
                "title": "The Great Glyph Grift",
                "excerpt": "A TrueType font flaw in CoreGraphics (CVE-2026-86950) gives an out-of-bounds write — patched in iOS 26.7.1.",
                "type": "news",
                "url": "https://calif.io/research/the-great-glyph-grift",
                "date": "2026-11-16T05:00:00+0000",
                "guid": "calif-glyph-grift-2026",
                "author": "Calif",
            ],
            [
                "title": "iOS 26.7.1 patches the CoreGraphics font bug",
                "excerpt": "Apple fixed CVE-2026-86950, the font parsing flaw behind the glyph grift research, in iOS 26.7.1.",
                "type": "news",
                "url": "https://calif.io/research/the-great-glyph-grift",
                "date": "2026-11-16T05:00:00+0000",
                "guid": "ios-2671-cve-2026-86950",
                "author": "Calif",
            ],
            [
                "title": "iOS 27.0.1 is no longer signed",
                "excerpt": "Apple stopped signing iOS 27.0.1 — iOS 27.2 is the only signed release for iPhone 14. A full restore now lands on 27.2.",
                "type": "news",
                "url": "https://ipsw.me/iPhone14,7",
                "date": "2026-11-09T05:00:00+0000",
                "guid": "ios-2701-unsigned-2026",
                "author": "ipsw.me",
            ],
        ]
        return raw.compactMap { NewsArticle(dict: $0) }
    }
    
    static let ShowNews = Notification.Name("Sileo.ShowNews")
}
