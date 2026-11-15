import Foundation
import Darwin

// Sileo demo (userland): the root privilege machinery was removed.
// - The macOS root helper (privileged launcher + root-daemon XPC helper) is gone.
// - spawnAsRoot no longer escalates: it reports failure (-1) so no caller
//   can mistake a privileged command for having run.
// - deleteFileAsRoot / hardLinkAsRoot / moveFileAsRoot only use the app's
//   own sandboxed FileManager operations.


@discardableResult func spawn(command: String, args: [String]) -> (Int, String, String) {
    var pipestdout: [Int32] = [0, 0]
    var pipestderr: [Int32] = [0, 0]

    let bufsiz = Int(BUFSIZ)

    pipe(&pipestdout)
    pipe(&pipestderr)

    guard fcntl(pipestdout[0], F_SETFL, O_NONBLOCK) != -1 else {
        return (-1, "", "")
    }
    guard fcntl(pipestderr[0], F_SETFL, O_NONBLOCK) != -1 else {
        return (-1, "", "")
    }

    var fileActions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&fileActions)
    posix_spawn_file_actions_addclose(&fileActions, pipestdout[0])
    posix_spawn_file_actions_addclose(&fileActions, pipestderr[0])
    posix_spawn_file_actions_adddup2(&fileActions, pipestdout[1], STDOUT_FILENO)
    posix_spawn_file_actions_adddup2(&fileActions, pipestderr[1], STDERR_FILENO)
    posix_spawn_file_actions_addclose(&fileActions, pipestdout[1])
    posix_spawn_file_actions_addclose(&fileActions, pipestderr[1])

    let argv: [UnsafeMutablePointer<CChar>?] = args.map { $0.withCString(strdup) }
    defer { for case let arg? in argv { free(arg) } }

    var pid: pid_t = 0

    #if targetEnvironment(macCatalyst)
    let env = [ "PATH=/opt/procursus/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin" ]
    let proenv: [UnsafeMutablePointer<CChar>?] = env.map { $0.withCString(strdup) }
    defer { for case let pro? in proenv { free(pro) } }
    let spawnStatus = posix_spawn(&pid, command, &fileActions, nil, argv + [nil], proenv + [nil])
    #else
    // Weird problem with a weird workaround
    let env = [ "PATH=\(CommandPath.prefix)/usr/bin:\(CommandPath.prefix)/usr/local/bin:\(CommandPath.prefix)/bin:\(CommandPath.prefix)/usr/sbin" ]
    let envp: [UnsafeMutablePointer<CChar>?] = env.map { $0.withCString(strdup) }
    defer { for case let env? in envp { free(env) } }
    
    // Sileo demo (userland): plain spawn as the app user. The old
    // persona-override branch (privilege escalation to uid/gid 0)
    // was removed.
    let spawnStatus = posix_spawn(&pid, command, &fileActions, nil, argv + [nil], envp + [nil])
    #endif
    if spawnStatus != 0 {
        return (Int(spawnStatus), "ITS FAILING HERE", "Error = \(errno)  \(String(cString: strerror(spawnStatus))) \(String(cString: strerror(errno)))\n\(command)")
    }

    close(pipestdout[1])
    close(pipestderr[1])

    var stdoutStr = ""
    var stderrStr = ""

    let mutex = DispatchSemaphore(value: 0)

    let readQueue = DispatchQueue(label: "org.coolstar.sileo.command",
                                  qos: .userInitiated,
                                  attributes: .concurrent,
                                  autoreleaseFrequency: .inherit,
                                  target: nil)

    let stdoutSource = DispatchSource.makeReadSource(fileDescriptor: pipestdout[0], queue: readQueue)
    let stderrSource = DispatchSource.makeReadSource(fileDescriptor: pipestderr[0], queue: readQueue)

    stdoutSource.setCancelHandler {
        close(pipestdout[0])
        mutex.signal()
    }
    stderrSource.setCancelHandler {
        close(pipestderr[0])
        mutex.signal()
    }

    stdoutSource.setEventHandler {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
        defer { buffer.deallocate() }

        let bytesRead = read(pipestdout[0], buffer, bufsiz)
        guard bytesRead > 0 else {
            if bytesRead == -1 && errno == EAGAIN {
                return
            }

            stdoutSource.cancel()
            return
        }

        let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
        array.withUnsafeBufferPointer { ptr in
            let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
            stdoutStr += str
        }
    }
    stderrSource.setEventHandler {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
        defer { buffer.deallocate() }

        let bytesRead = read(pipestderr[0], buffer, bufsiz)
        guard bytesRead > 0 else {
            if bytesRead == -1 && errno == EAGAIN {
                return
            }

            stderrSource.cancel()
            return
        }

        let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
        array.withUnsafeBufferPointer { ptr in
            let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
            stderrStr += str
        }
    }

    stdoutSource.resume()
    stderrSource.resume()

    mutex.wait()
    mutex.wait()
    var status: Int32 = 0
    waitpid(pid, &status, 0)

    return (Int(status), stdoutStr, stderrStr)
}

@discardableResult func spawnAsRoot(args: [String], platformatise: Bool = false, outputCallback: ((_ output: String?) -> Void)? = nil) -> (Int, String, String) {
    // Sileo demo (userland): privileged execution is not available.
    // Returning -1 (failure) so no caller can mistake this for success.
    // The old paths (persona override on iOS 13+, the setuid helper on
    // older iOS, the macOS root helper on macCatalyst) are gone.
    return (-1, "", "")
}

func deleteFileAsRoot(_ url: URL) {
    // Sileo demo (userland): plain sandboxed delete, never via root.
    try? FileManager.default.removeItem(at: url)
}

func hardLinkAsRoot(from: URL, to: URL) {
    deleteFileAsRoot(to)

    // Sileo demo (userland): plain sandboxed symlink, no root chown/chmod.
    try? FileManager.default.createSymbolicLink(at: to, withDestinationURL: from)
}

func moveFileAsRoot(from: URL, to: URL) {
    deleteFileAsRoot(to)

    // Sileo demo (userland): plain sandboxed move, no root chown/chmod.
    try? FileManager.default.moveItem(at: from, to: to)
}

