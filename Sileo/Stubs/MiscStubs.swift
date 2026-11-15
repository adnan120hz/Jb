// Sileo demo (userland) stubs — replace the remaining small backend types the
// UI references:
//
// - DatabaseManager (was Sileo/Backend/DatabaseManager/DatabaseManager.swift):
//   the real one kept a SQLite database of seen packages. The demo has no
//   database; markAsSeen is a no-op. NOTE: this stub deliberately has NO
//   `.database` property — PackageStub.timestamps() was stubbed to [] for
//   the same reason. Do NOT copy UIDevice+Private.swift here: it dlopened
//   libMobileGestalt to read the real UDID, which the demo must not do.
// - UIDevice helpers (public sysctl only; uniqueIdentifier is "" —
//   the real UDID is not readable on stock iOS and is not needed).
// - ICloudPFPHandler (was Sileo/Backend/Extensions/FolderFinder.swift):
//   the real one fetched the iCloud profile picture; the demo returns nil
//   so the UI falls back to its default avatar.

import Foundation
import UIKit

final class DatabaseManager {

    static let shared = DatabaseManager()

    private init() {}

    public func markAsSeen(_ dataPackage: Package) {
        // Sileo demo (userland): no database exists to record this in.
    }
}

extension UIDevice {

    var kernOSType: String {
        return UIDevice.sysctlString("kern.ostype")
    }

    var kernOSRelease: String {
        return UIDevice.sysctlString("kern.osrelease")
    }

    /// Hardware model string, e.g. "iPhone14,7" (public sysctl, no private API).
    var platform: String {
        return UIDevice.sysctlString("hw.machine")
    }

    /// The real UDID is not readable on stock iOS; the demo reports none.
    var uniqueIdentifier: String {
        return ""
    }

    /// Device headers sent with repo requests; the demo sends none.
    var headers: [String: String] {
        return [:]
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
}

final class ICloudPFPHandler {

    static func refreshiCloudPicture(_ completion: @escaping (UIImage) -> Void) -> UIImage? {
        // Sileo demo (userland): no iCloud picture is fetched; the caller
        // falls back to its default avatar. The completion is never called.
        return nil
    }
}
