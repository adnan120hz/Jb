// Sileo demo (userland) stub — replaces Sileo/Backend/Control File Parser/ControlFileParser.swift
//
// The real parser read dpkg control files. The demo has no control files to
// parse, so dictionary() returns an empty control dictionary. authorName /
// authorEmail are pure string parsers for "Name <email>" (the two methods
// the UI calls; no definition of them existed anywhere in the tree, so this
// stub supplies them with the exact signatures the UI uses).

import Foundation

struct PackageTags: OptionSet {
    let rawValue: Int

    static let none = PackageTags([])
    static let commercial = PackageTags(rawValue: 1)
    static let sileo = PackageTags(rawValue: 2)
}

final class ControlFileParser {

    class func dictionary(controlFile: String, isReleaseFile: Bool = false) throws -> ([String: String], PackageTags) {
        // Sileo demo (userland): no control files exist to parse.
        return ([:], .none)
    }

    class func dictionary(controlData: Data, isReleaseFile: Bool = false) throws -> ([String: String], PackageTags) {
        // Sileo demo (userland): no control data exists to parse.
        return ([:], .none)
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
