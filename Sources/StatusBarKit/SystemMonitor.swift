import Foundation
import Darwin

/// System statistics snapshot.
public struct SystemStats: Sendable, Equatable {
    public let availableMemoryBytes: UInt64
    public let totalMemoryBytes: UInt64
    public let cpuUsagePercent: Double

    public var availableMemoryGB: Double {
        Double(availableMemoryBytes) / 1_073_741_824
    }

    public var totalMemoryGB: Double {
        Double(totalMemoryBytes) / 1_073_741_824
    }

    public static let zero = SystemStats(
        availableMemoryBytes: 0, totalMemoryBytes: 0, cpuUsagePercent: 0)
}

/// CPU tick counts for calculating usage deltas.
public struct CPUTicks: Sendable, Equatable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64

    public var total: UInt64 { user + system + idle + nice }
    public var active: UInt64 { user + system + nice }

    public static let zero = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
}

/// Provides system memory and CPU statistics via Mach APIs.
public enum SystemMonitor {

    /// Returns available and total memory in bytes.
    public static func getMemoryStats() -> (available: UInt64, total: UInt64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else {
            return (0, total)
        }

        let pageSize = UInt64(getpagesize())
        let available =
            (UInt64(stats.free_count)
                + UInt64(stats.inactive_count)
                + UInt64(stats.purgeable_count)) * pageSize

        return (available, total)
    }

    /// Returns current aggregate CPU tick counts.
    public static func getCPUTicks() -> CPUTicks {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return .zero
        }

        defer {
            let size = vm_size_t(Int(numCPUInfo) * MemoryLayout<integer_t>.size)
            vm_deallocate(
                mach_task_self_, vm_address_t(Int(bitPattern: info)), size)
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += UInt64(info[offset + Int(CPU_STATE_USER)])
            totalSystem += UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(info[offset + Int(CPU_STATE_IDLE)])
            totalNice += UInt64(info[offset + Int(CPU_STATE_NICE)])
        }

        return CPUTicks(
            user: totalUser, system: totalSystem, idle: totalIdle, nice: totalNice)
    }

    /// Calculates CPU usage percentage from two tick snapshots.
    public static func cpuUsage(previous: CPUTicks, current: CPUTicks) -> Double {
        guard current.total >= previous.total else { return 0 }
        let totalDelta = current.total - previous.total
        guard totalDelta > 0 else { return 0 }
        guard current.active >= previous.active else { return 0 }
        let activeDelta = current.active - previous.active
        return min(Double(activeDelta) / Double(totalDelta) * 100.0, 100.0)
    }
}
