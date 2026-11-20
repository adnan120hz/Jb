// Sileo demo (userland) — real Debian control-file parser.
//
// The demo fetches real repo Packages/Release files over plain HTTPS and
// parses them here. No privilege, no jailbreak code: this is pure string
// parsing of public repo metadata. The parsed dictionaries feed
// PackageListManager, so the Sources/Featured/Search UI shows real packages
// and the Tweaks category can be browsed. Installation is still impossible
// on stock iOS — see APTWrapper.

import Foundation

struct PackageTags: OptionSet {
    let rawValue: Int

    static let none = PackageTags([])
    static let commercial = PackageTags(rawValue: 1)
    static let sileo = PackageTags(rawValue: 2)
}

final class ControlFileParser {

    /// Parse one control paragraph ("Key: Value" lines, continuation lines
    /// start with a space/tab) into a lowercase-keyed dictionary.
    class func dictionary(controlFile: String, isReleaseFile: Bool = false) throws -> ([String: String], PackageTags) {
        var dict: [String: String] = [:]
        var currentKey: String?
        for rawLine in controlFile.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .init(charactersIn: "\r"))
            if line.isEmpty { continue }
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                // Continuation of the previous field.
                if let key = currentKey, let existing = dict[key] {
                    dict[key] = existing + "\n" + line.trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            dict[key] = value
            currentKey = key
        }
        var tags: PackageTags = .none
        if let tagField = dict["tag"] {
            let lower = tagField.lowercased()
            if lower.contains("commercial") { tags.insert(.commercial) }
            if lower.contains("sileo") { tags.insert(.sileo) }
        }
        if dict["sileodepiction"] != nil { tags.insert(.sileo) }
        return (dict, tags)
    }

    class func dictionary(controlData: Data, isReleaseFile: Bool = false) throws -> ([String: String], PackageTags) {
        guard let text = String(data: controlData, encoding: .utf8) ??
                         String(data: controlData, encoding: .isoLatin1) else {
            return ([:], .none)
        }
        return try dictionary(controlFile: text, isReleaseFile: isReleaseFile)
    }

    /// Split a Packages file into its paragraphs and parse each one.
    /// Returns one dictionary per package entry.
    class func dictionaries(controlFile: String) -> [([String: String], PackageTags)] {
        // Paragraphs are separated by one or more blank lines.
        let normalized = controlFile.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = normalized.components(separatedBy: "\n\n")
        var out: [([String: String], PackageTags)] = []
        out.reserveCapacity(paragraphs.count)
        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if let parsed = try? dictionary(controlFile: trimmed) {
                out.append(parsed)
            }
        }
        return out
    }

    /// "Jane Doe <jane@example.com>" -> "Jane Doe"; a bare name is returned as-is.
    class func authorName(string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let bracket = trimmed.firstIndex(of: "<") {
            return String(trimmed[..<bracket]).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }

    /// "Jane Doe <jane@example.com>" -> "jane@example.com"; nil when no address is present.
    class func authorEmail(string: String) -> String? {
        guard let open = string.firstIndex(of: "<"),
              let close = string.firstIndex(of: ">"),
              open < close else { return nil }
        let email = String(string[string.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
        return email.isEmpty ? nil : email
    }
}
