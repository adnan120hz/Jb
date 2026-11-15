//
//  APTWrapper.swift
//  Sileo
//
//  Created by CoolStar on 8/24/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import Evander

class APTWrapper {
    static let sileoFD = 6
    static let cydiaCompatFd = 6
    static let debugFD = 11

    public enum FINISH: Int {
        case back = 0
        case uicache = 1
        case reopen = 2
        case restart = 3
        case reload = 4
        case reboot = 5
        case usreboot = 6
    }

    static let GNUPGPREFIX = "[GNUPG:]"
    static let GNUPGBADSIG = "[GNUPG:] BADSIG"
    static let GNUPGERRSIG = "[GNUPG:] ERRSIG"
    static let GNUPGNOPUBKEY = "[GNUPG:] NO_PUBKEY"
    static let GNUPGVALIDSIG = "[GNUPG:] VALIDSIG"
    static let GNUPGGOODSIG = "[GNUPG:] GOODSIG"
    static let GNUPGEXPKEYSIG = "[GNUPG:] EXPKEYSIG"
    static let GNUPGEXPSIG = "[GNUPG:] EXPSIG"
    static let GNUPGREVKEYSIG = "[GNUPG:] REVKEYSIG"
    static let GNUPGNODATA = "[GNUPG:] NODATA"
    static let APTKEYWARNING = "[APTKEY:] WARNING"
    static let APTKEYERROR = "[APTKEY:] ERROR"

    enum DigestState {
        case untrusted,
        weak,
        trusted
    }

    struct Digest {
        let state: DigestState
        let name: String
    }

    static let digests: [Digest] = [
        Digest(state: .untrusted, name: "Invalid Digest"),
        Digest(state: .untrusted, name: "MD5"),
        Digest(state: .untrusted, name: "SHA1"),
        Digest(state: .untrusted, name: "RIPE-MD/160"),
        Digest(state: .untrusted, name: "Reserved digest"),
        Digest(state: .untrusted, name: "Reserved digest"),
        Digest(state: .untrusted, name: "Reserved digest"),
        Digest(state: .untrusted, name: "Reserved digest"),
        Digest(state: .trusted, name: "SHA256"),
        Digest(state: .trusted, name: "SHA384"),
        Digest(state: .trusted, name: "SHA512"),
        Digest(state: .trusted, name: "SHA224")
    ]

    class func dictionaryOfScannedApps() -> [String: Int64] {
        var dictionary: [String: Int64] = [:]
        let fileManager = FileManager.default

        guard let apps = try? fileManager.contentsOfDirectory(atPath: "\(CommandPath.prefix)/Applications") else {
            return dictionary
        }

        for app in apps {
            let infoPlist = String(format: "\(CommandPath.prefix)/Applications/%@/Info.plist", app)

            guard let attr = try? fileManager.attributesOfItem(atPath: infoPlist) else {
                continue
            }

            let fileNumber = attr[FileAttributeKey.systemFileNumber] as? Int64
            dictionary[app] = fileNumber
        }
        return dictionary
    }

    public class func installProgress(aptStatus: String) -> (Bool, Double, String, String) {
        let statusParts = aptStatus.components(separatedBy: ":")
        if statusParts.count < 4 {
            return (false, 0, "", "")
        }
        if statusParts[0] != "pmstatus" {
            return (false, 0, "", "")
        }

        let packageName = statusParts[1]
        guard let rawProgress = Double(statusParts[2]) else {
            return (false, 0, "", "")
        }
        let statusReadable = statusParts[3]
        return (true, rawProgress, statusReadable, packageName)
    }

    public class func verifySignature(key: String, data: String, error: inout String) -> Bool {
        #if targetEnvironment(simulator) || TARGET_SANDBOX

        error = "GnuPG not available in sandboxed environment"
        return false

        #else

        let (_, output, _) = spawn(command: CommandPath.sh, args: ["sh", CommandPath.aptkey, "verify", "-q", "--status-fd", "1", key, data])

        let outputLines = output.components(separatedBy: "\n")

        var keyIsGood = false
        var keyIsTrusted = false

        let substrCount = GNUPGPREFIX.count + 1

        for outputLine in outputLines {
            for prefix in [GNUPGBADSIG, GNUPGERRSIG, GNUPGEXPSIG, GNUPGREVKEYSIG, GNUPGNOPUBKEY, GNUPGNODATA] {
                if outputLine.hasPrefix(prefix) {
                    let index = outputLine.index(outputLine.startIndex, offsetBy: substrCount)
                    error = String(outputLine[index...])
                    keyIsGood = false
                }
            }
            if outputLine.hasPrefix(GNUPGGOODSIG) {
                keyIsGood = true
            }
            if outputLine.hasPrefix(GNUPGVALIDSIG) {
                let sigComponents = outputLine.components(separatedBy: " ")
                if sigComponents.count < 10 {
                    continue
                }

                // let sig = sigComponents[2]
                let digestType = sigComponents[9]

                guard let digestIdx = Int(digestType),
                    digestIdx <= digests.count else {
                        continue
                }

                let digest = digests[digestIdx]
                if digest.state == .trusted {
                    keyIsTrusted = true
                }
            }
        }
        return keyIsGood && keyIsTrusted

        #endif
    }

    public class func performOperations(installs: [DownloadPackage],
                                        removals: [DownloadPackage],
                                        installDeps: [DownloadPackage],
                                        progressCallback: @escaping (Double, Bool, String, String) -> Void,
                                        outputCallback: @escaping (String, Int) -> Void,
                                        completionCallback: @escaping (Int, FINISH, Bool) -> Void) {
        // Sileo demo (userland): package installation is not available.
        // The old apt-get-as-root machinery (persona override on iOS 13+,
        // the setuid helper on older iOS, the macOS root helper on
        // macCatalyst, uicache-as-root and apt-get clean as root) was removed.
        // Report failure honestly instead of pretending the install
        // succeeded: status 1, no refresh, and a visible message in
        // the install log.
        outputCallback("Package installation is not available in this userland demo.\n", Int(STDOUT_FILENO))
        completionCallback(1, .back, false)
    }
}
