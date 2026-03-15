import Foundation
import Observation

/// Combined observable state for the status bar, refreshing every second.
@Observable
@MainActor
public final class MonitorState {
    public private(set) var stats: SystemStats = .zero
    public private(set) var builds: [BuildProcess] = []

    private var previousTicks: CPUTicks? = nil

    public var menuBarText: String {
        let memColor: String
        if stats.availableMemoryGB > 8 {
            memColor = "🟢"
        } else if stats.availableMemoryGB > 4 {
            memColor = "🟡"
        } else {
            memColor = "🔴"
        }

        let mem = String(format: "%.1fG", stats.availableMemoryGB)
        let cpu = String(format: "%.0f%%", stats.cpuUsagePercent)

        return "\(memColor) \(mem) │ CPU \(cpu) │ 🔨 \(builds.count)"
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

        builds = BuildMonitor.getActiveBuilds()
    }
}
