import Foundation
import Observation

/// Combined observable state for the status bar, refreshing every second.
@Observable
@MainActor
public final class MonitorState {
    public private(set) var stats: SystemStats = .zero
    public private(set) var builds: [BuildProcess] = []

    private var previousTicks: CPUTicks? = nil
    private var previousBuildCpuTimes: [Int32: Double] = [:]

    public var memoryText: String {
        String(format: "%4.1fG", stats.availableMemoryGB)
    }

    public var cpuText: String {
        String(format: "%2.0f%%", stats.cpuUsagePercent)
    }

    public var compactLabel: String {
        var parts = [memoryText]

        if stats.cpuUsagePercent >= 10 {
            parts.append("CPU \(cpuText)")
        }

        if !builds.isEmpty {
            parts.append("🔨 \(builds.count)")
        }

        return parts.joined(separator: " │ ")
    }

    public var menuBarText: String {
        compactLabel
    }

    public init() {
        previousTicks = SystemMonitor.getCPUTicks()
        refresh()

        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.refresh()
            }
        }
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

        var newBuilds = BuildMonitor.getActiveBuilds()
        var newCpuTimes: [Int32: Double] = [:]
        for i in newBuilds.indices {
            let pid = newBuilds[i].pid
            newCpuTimes[pid] = newBuilds[i].cpuTimeSeconds
            if let prev = previousBuildCpuTimes[pid] {
                // Delta CPU seconds over ~1 second interval → percentage of one core
                newBuilds[i].cpuPercent = max(0, newBuilds[i].cpuTimeSeconds - prev) * 100.0
            }
        }
        previousBuildCpuTimes = newCpuTimes
        builds = newBuilds
    }
}
