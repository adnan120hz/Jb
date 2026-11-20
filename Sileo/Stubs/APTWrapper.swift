// Sileo demo (userland) stub — replaces Sileo/Backend/APT Wrapper/APTWrapper.swift
//
// The real APTWrapper ran apt-get as root (persona override / setuid helper /
// macOS root helper). That machinery is gone. performOperations reports failure
// honestly and finishes with .restart so the existing Downloads UI reaches
// its completion state, which just dismisses. Nothing here claims an
// install succeeded.

import Foundation

class APTWrapper {

    public enum FINISH: Int {
        case back = 0
        case uicache = 1
        case reopen = 2
        case restart = 3
        case reload = 4
        case reboot = 5
        case usreboot = 6
    }

    static let sileoFD = 6
    static let cydiaCompatFd = 6
    static let debugFD = 11

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

    public class func performOperations(installs: [DownloadPackage],
                                        removals: [DownloadPackage],
                                        installDeps: [DownloadPackage],
                                        progressCallback: @escaping (Double, Bool, String, String) -> Void,
                                        outputCallback: @escaping (String, Int) -> Void,
                                        completionCallback: @escaping (Int, FINISH, Bool) -> Void) {
        // Sileo demo (userland): package installation is not available.
        // The queued .deb files were downloaded to the app's
        // Documents/Downloads folder (Files app > On My iPhone > Sileo >
        // Downloads). Report failure honestly instead of pretending the
        // install succeeded: status 1, no refresh, and a visible message
        // in the install log. Finish with .restart so the Downloads UI
        // reaches its completion state, which just dismisses.
        // The demo performs no system action.
        outputCallback("Package installation is not available on stock iOS.\n", Int(STDOUT_FILENO))
        outputCallback("The .deb files were saved to Documents/Downloads (Files app > On My iPhone > Sileo > Downloads).\n", Int(STDOUT_FILENO))
        outputCallback("No package was installed.\n", Int(STDOUT_FILENO))
        completionCallback(1, .restart, false)
    }
}
