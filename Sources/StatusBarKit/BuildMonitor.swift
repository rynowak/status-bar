import Foundation
import Darwin

/// Represents a detected .NET build process.
public struct BuildProcess: Sendable, Identifiable, Equatable {
    public let pid: Int32
    public let kind: Kind
    public let projectName: String?
    public let arguments: [String]
    public let residentMemoryBytes: UInt64
    public let cpuTimeSeconds: Double
    public var cpuPercent: Double = 0

    public var id: Int32 { pid }

    public enum Kind: String, Sendable, Equatable {
        case dotnetBuild = "dotnet build"
        case dotnetMSBuild = "dotnet msbuild"
        case msbuildWorker = "MSBuild worker"
        case vbcsCompiler = "VBCSCompiler"
        case vsBuildServer = "VS Code build server"
        case vsCodeServer = "VS Code server"
        case vsCodeServiceHost = "VS Code service host"
        case vsCodeServiceController = "VS Code service controller"
        case roslynLanguageServer = "Roslyn language server"
    }

    public var displayName: String {
        if let projectName {
            return "\(kind.rawValue) — \(projectName)"
        }
        return kind.rawValue
    }

    public var memoryGB: Double {
        Double(residentMemoryBytes) / 1_073_741_824
    }
}

/// Scans the process table for .NET build-related processes.
public enum BuildMonitor {

    /// Process names to scan for in the process table.
    static let trackedProcessNames: Set<String> = [
        "dotnet", "VBCSCompiler",
        "Microsoft.Visual",  // Code.Server, Code.ServiceHost, Code.ServiceController
        "Microsoft.CodeAn",  // CodeAnalysis.LanguageServer
    ]

    /// Returns all active .NET build processes.
    public static func getActiveBuilds() -> [BuildProcess] {
        var results: [BuildProcess] = []

        for (pid, processName) in getBuildPids() {
            let (mem, cpu) = getProcessResourceUsage(pid: pid)

            // VBCSCompiler runs as its own binary, no need to parse args
            if processName == "VBCSCompiler" {
                results.append(
                    BuildProcess(
                        pid: pid, kind: .vbcsCompiler, projectName: nil,
                        arguments: [],
                        residentMemoryBytes: mem, cpuTimeSeconds: cpu))
                continue
            }

            guard let args = getProcessArguments(pid: pid), !args.isEmpty else { continue }

            // Native VS Code extension processes: classify by executable basename in argv[0]
            if processName.hasPrefix("Microsoft.") {
                guard let kind = classifyNativeProcess(executable: args[0]) else { continue }
                results.append(
                    BuildProcess(
                        pid: pid, kind: kind, projectName: nil,
                        arguments: args,
                        residentMemoryBytes: mem, cpuTimeSeconds: cpu))
                continue
            }

            guard let kind = classify(arguments: args) else { continue }

            let projectName = extractProjectName(from: args)
            results.append(
                BuildProcess(
                    pid: pid,
                    kind: kind,
                    projectName: projectName,
                    arguments: args,
                    residentMemoryBytes: mem,
                    cpuTimeSeconds: cpu
                ))
        }

        return results
    }

    /// Classifies a dotnet process based on its arguments.
    public static func classify(arguments: [String]) -> BuildProcess.Kind? {
        // Check for VBCSCompiler in any argument (can also run as dotnet exec VBCSCompiler.dll)
        for arg in arguments {
            if arg.contains("VBCSCompiler") {
                return .vbcsCompiler
            }
        }

        guard arguments.count > 1 else { return nil }
        let subcommand = (arguments[1] as NSString).lastPathComponent.lowercased()

        // MSBuild worker nodes: dotnet MSBuild.dll /nodemode:1
        if subcommand == "msbuild.dll" {
            return .msbuildWorker
        }

        // VS Code C# Dev Kit build server: dotnet ...BuildHost.dll
        if subcommand.hasSuffix("buildhost.dll") {
            return .vsBuildServer
        }

        switch subcommand {
        case "build":
            return .dotnetBuild
        case "msbuild":
            return .dotnetMSBuild
        default:
            return nil
        }
    }

    /// Classifies a native VS Code extension process by its executable path.
    static func classifyNativeProcess(executable: String) -> BuildProcess.Kind? {
        switch (executable as NSString).lastPathComponent {
        case "Microsoft.VisualStudio.Code.Server":
            return .vsCodeServer
        case "Microsoft.VisualStudio.Code.ServiceHost":
            return .vsCodeServiceHost
        case "Microsoft.VisualStudio.Code.ServiceController":
            return .vsCodeServiceController
        case "Microsoft.CodeAnalysis.LanguageServer":
            return .roslynLanguageServer
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

    /// Lists PIDs of all tracked build-related processes using sysctl.
    static func getBuildPids() -> [(pid: pid_t, name: String)] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: size_t = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }

        let count = size / MemoryLayout<kinfo_proc>.size
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return [] }

        let actualCount = size / MemoryLayout<kinfo_proc>.size
        var results: [(pid: pid_t, name: String)] = []

        for i in 0..<actualCount {
            let proc = procs[i]
            let name = withUnsafePointer(to: proc.kp_proc.p_comm) {
                String(
                    cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
            }
            if trackedProcessNames.contains(name) {
                results.append((pid: proc.kp_proc.p_pid, name: name))
            }
        }

        return results
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

    /// Returns resident memory (bytes) and total CPU time (seconds) for a process.
    static func getProcessResourceUsage(pid: pid_t) -> (memory: UInt64, cpuTime: Double) {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        guard result == size else { return (0, 0) }

        let mem = UInt64(info.pti_resident_size)
        let cpuNanos = Double(info.pti_total_user + info.pti_total_system)
        return (mem, cpuNanos / 1_000_000_000)
    }
}
