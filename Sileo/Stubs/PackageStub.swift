//
//  PackageStub.swift
//  Sileo
//
//  Created by CoolStar on 8/17/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

struct PackageStub: Codable {
    
    public var package: String
    public var version: String
    public var repoURL: String
    public var guid: String
    
    public var firstSeenDate = Date()
    public var userReadDate: Int64?
    public var firstSeen: Int64?
    
    static func timestamps() -> [Int64] {
        // Sileo demo (userland): no package database exists.
        return []
    }

    init(from package: Package) {
        self.package = package.package
        self.version = package.version
        self.repoURL = package.sourceFileURL?.lastPathComponent ?? "status"
        self.guid = "\(self.package)-\(self.version)"
    }
    
    public init(packageName: String, version: String, source: String) {
        self.package = packageName
        self.version = version
        self.repoURL = source
        self.guid = "\(self.package)-\(self.version)"
    }

}
