import Foundation
import Observation

/// Combined observable state for the status bar, refreshing every second.
@Observable
@MainActor
public final class MonitorState {
    public private(set) var stats: SystemStats = .zero
    public private(set) var cpuHistory: [Double] = []
    public private(set) var builds: [BuildProcess] = []
    public private(set) var vsCodeProcesses: [BuildProcess] = []
    public private(set) var composeProjects: [ComposeProject] = []
    public private(set) var killingProjects: Set<String> = []

    public var showSystemStats: Bool {
        didSet { UserDefaults.standard.set(showSystemStats, forKey: "showSystemStats") }
    }

    private static let maxCPUHistory = 60

    private var previousTicks: CPUTicks? = nil
    private var previousBuildCpuTimes: [Int32: Double] = [:]
    private var composeTickCounter = 0

    public var memoryText: String {
        let usedGB = stats.totalMemoryGB - stats.availableMemoryGB
        return String(format: "%.0fG", usedGB)
    }

    public var cpuText: String {
        String(format: "%2.0f%%", stats.cpuUsagePercent)
    }

    public var compactLabel: String {
        var parts: [String] = []

        if !builds.isEmpty {
            parts.append("🔨\(builds.count)")
        }

        return parts.joined(separator: " ")
    }

    public var menuBarText: String {
        compactLabel
    }

    public init() {
        UserDefaults.standard.register(defaults: ["showSystemStats": true])
        showSystemStats = UserDefaults.standard.bool(forKey: "showSystemStats")
        previousTicks = SystemMonitor.getCPUTicks()
        refresh()

        Task { [weak self] in
            while true {
                try await Task.sleep(for: .seconds(2))
                guard let self else { return }
                self.refresh()
            }
        }
    }

    public func killComposeProject(project: String) {
        killingProjects.insert(project)
        Task {
            await Self.performRemoveProject(project: project)
            self.killingProjects.remove(project)
            self.refreshCompose()
        }
    }

    nonisolated private static func performRemoveProject(project: String) async {
        ComposeMonitor.removeProject(project: project)
    }

    private func refresh() {
        let currentTicks = SystemMonitor.getCPUTicks()
        let cpuUsage: Double
        if let prev = previousTicks {
            cpuUsage = SystemMonitor.cpuUsage(previous: prev, current: currentTicks)
        } else {
            cpuUsage = 0
        }
        previousTicks = currentTicks

        let memory = SystemMonitor.getMemoryStats()
        stats = SystemStats(
            availableMemoryBytes: memory.available,
            totalMemoryBytes: memory.total,
            cpuUsagePercent: cpuUsage
        )

        cpuHistory.append(cpuUsage)
        if cpuHistory.count > Self.maxCPUHistory {
            cpuHistory.removeFirst(cpuHistory.count - Self.maxCPUHistory)
        }

        var newBuilds = BuildMonitor.getActiveBuilds()
        var newCpuTimes: [Int32: Double] = [:]
        for i in newBuilds.indices {
            let pid = newBuilds[i].pid
            newCpuTimes[pid] = newBuilds[i].cpuTimeSeconds
            if let prev = previousBuildCpuTimes[pid] {
                newBuilds[i].cpuPercent = max(0, newBuilds[i].cpuTimeSeconds - prev) * 100.0
            }
        }
        previousBuildCpuTimes = newCpuTimes
        builds = newBuilds.filter { !$0.isVSCodeProcess }
        vsCodeProcesses = newBuilds.filter { $0.isVSCodeProcess }

        composeTickCounter += 1
        if composeTickCounter == 1 || composeTickCounter % 5 == 0 {
            refreshCompose()
        }
    }

    private func refreshCompose() {
        Task {
            let projects = await Self.fetchComposeProjects()
            self.composeProjects = projects
        }
    }

    nonisolated private static func fetchComposeProjects() async -> [ComposeProject] {
        ComposeMonitor.getMonetProjects()
    }
}
