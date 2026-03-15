import Foundation
import Darwin

/// Represents a detected .NET build process.
public struct BuildProcess: Sendable, Identifiable, Equatable {
    public let pid: Int32
    public let kind: Kind
    public let projectName: String?
    public let arguments: [String]

    public var id: Int32 { pid }

    public enum Kind: String, Sendable, Equatable {
        case dotnetBuild = "dotnet build"
        case dotnetMSBuild = "dotnet msbuild"
        case vbcsCompiler = "VBCSCompiler"
    }

    public var displayName: String {
        if let projectName {
            return "\(kind.rawValue) — \(projectName)"
        }
        return kind.rawValue
    }
}

/// Scans the process table for .NET build-related processes.
public enum BuildMonitor {

    /// Returns all active .NET build processes.
    public static func getActiveBuilds() -> [BuildProcess] {
        var results: [BuildProcess] = []

        for pid in getDotnetPids() {
            guard let args = getProcessArguments(pid: pid), !args.isEmpty else { continue }
            guard let kind = classify(arguments: args) else { continue }

            let projectName = extractProjectName(from: args)
            results.append(
                BuildProcess(
                    pid: pid,
                    kind: kind,
                    projectName: projectName,
                    arguments: args
                ))
        }

        return results
    }

    /// Classifies a dotnet process based on its arguments.
    public static func classify(arguments: [String]) -> BuildProcess.Kind? {
        // Check for VBCSCompiler in any argument (it runs as dotnet exec VBCSCompiler.dll)
        for arg in arguments {
            if arg.contains("VBCSCompiler") {
                return .vbcsCompiler
            }
        }

        // Look for the subcommand (first argument after the dotnet executable path)
        guard arguments.count > 1 else { return nil }
        let subcommand = arguments[1].lowercased()

        switch subcommand {
        case "build":
            return .dotnetBuild
        case "msbuild":
            return .dotnetMSBuild
        default:
            return nil
        }
    }

    /// Extracts a project file name from command line arguments.
    public static func extractProjectName(from arguments: [String]) -> String? {
        let projectExtensions = [".csproj", ".fsproj", ".vbproj", ".sln"]
        for arg in arguments {
            let lower = arg.lowercased()
            for ext in projectExtensions {
                if lower.hasSuffix(ext) {
                    return (arg as NSString).lastPathComponent
                }
            }
        }
        return nil
    }

    // MARK: - Private

    /// Lists PIDs of all running dotnet processes using sysctl.
    static func getDotnetPids() -> [pid_t] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: size_t = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }

        let count = size / MemoryLayout<kinfo_proc>.size
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return [] }

        let actualCount = size / MemoryLayout<kinfo_proc>.size
        var pids: [pid_t] = []

        for i in 0..<actualCount {
            let proc = procs[i]
            let name = withUnsafePointer(to: proc.kp_proc.p_comm) {
                String(
                    cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
            }
            if name == "dotnet" {
                pids.append(proc.kp_proc.p_pid)
            }
        }

        return pids
    }

    /// Reads the command line arguments for a process using sysctl KERN_PROCARGS2.
    static func getProcessArguments(pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: size_t = 0

        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        guard size >= MemoryLayout<Int32>.size else { return nil }

        // First 4 bytes are argc
        let argc: Int32 = buffer.withUnsafeBufferPointer { buf in
            buf.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        }

        var offset = MemoryLayout<Int32>.size

        // Skip the exec path (null-terminated)
        while offset < size && buffer[offset] != 0 { offset += 1 }
        // Skip null padding between exec path and first argument
        while offset < size && buffer[offset] == 0 { offset += 1 }

        // Read argc null-terminated argument strings
        var args: [String] = []
        for _ in 0..<argc {
            guard offset < size else { break }
            var end = offset
            while end < size && buffer[end] != 0 { end += 1 }
            if let str = String(bytes: buffer[offset..<end], encoding: .utf8) {
                args.append(str)
            }
            offset = end + 1
        }

        return args.isEmpty ? nil : args
    }
}
