import Foundation

public struct ComposeProject: Sendable, Identifiable {
    public let name: String
    public let configFiles: String
    public let services: [ComposeService]

    public var id: String { name }

    public var activeServices: [ComposeService] {
        services.filter { !($0.state == "exited" && $0.exitCode == 0) }
    }

    public var runningCount: Int {
        services.filter(\.isRunning).count
    }

    public var activeCount: Int {
        activeServices.count
    }

    public var isHealthy: Bool {
        runningCount == activeCount && activeCount > 0
    }
}

public struct ComposeService: Sendable, Identifiable {
    public let service: String
    public let state: String
    public let health: String
    public let exitCode: Int

    public var id: String { service }
    public var isRunning: Bool { state == "running" }
}

public enum ComposeMonitor {

    private static let dockerSearchPaths = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker",
    ]

    public static func getMonetProjects() -> [ComposeProject] {
        guard let docker = findDocker() else { return [] }
        guard let lsOutput = runCommand([docker, "compose", "ls", "--format", "json"]) else {
            return []
        }

        let allProjects = parseProjectList(lsOutput)
        let monetProjects = allProjects.filter { isMonetProject(configFiles: $0.configFiles) }

        return monetProjects.map { project in
            let services = getServices(docker: docker, project: project.name)
            return ComposeProject(
                name: project.name,
                configFiles: project.configFiles,
                services: services
            )
        }
    }

    static func parseProjectList(_ output: String) -> [(name: String, configFiles: String)] {
        guard let data = output.data(using: .utf8) else { return [] }

        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap { dict in
                guard let name = dict["Name"] as? String,
                    let configFiles = dict["ConfigFiles"] as? String
                else { return nil }
                return (name: name, configFiles: configFiles)
            }
        }

        return output.components(separatedBy: "\n").compactMap {
            line -> (name: String, configFiles: String)? in
            guard !line.isEmpty,
                let lineData = line.data(using: .utf8),
                let dict = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                let name = dict["Name"] as? String,
                let configFiles = dict["ConfigFiles"] as? String
            else { return nil }
            return (name: name, configFiles: configFiles)
        }
    }

    static func getServices(docker: String, project: String) -> [ComposeService] {
        guard
            let output = runCommand([
                docker, "compose", "-p", project, "ps", "-a", "--format", "json",
            ])
        else {
            return []
        }

        var services: [ComposeService] = []
        var seen = Set<String>()

        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let service = dict["Service"] as? String,
                let state = dict["State"] as? String
            else { continue }

            guard !seen.contains(service) else { continue }
            seen.insert(service)

            let health = dict["Health"] as? String ?? ""
            let exitCode = dict["ExitCode"] as? Int ?? 0

            services.append(
                ComposeService(
                    service: service,
                    state: state,
                    health: health,
                    exitCode: exitCode
                ))
        }

        return services.sorted { $0.service < $1.service }
    }

    static func isMonetProject(configFiles: String) -> Bool {
        let lowered = configFiles.lowercased()
        return lowered.contains("/monet/") || lowered.hasSuffix("/monet")
    }

    static func findDocker() -> String? {
        dockerSearchPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func runCommand(_ args: [String]) -> String? {
        guard !args.isEmpty else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
