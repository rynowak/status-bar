import SwiftUI
import ServiceManagement
import StatusBarKit

struct ContentView: View {
    let state: MonitorState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            systemSection
            Divider()
            buildsSection
            Divider()
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 320)
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("System")
                .font(.headline)

            HStack {
                Text("Memory:")
                Spacer()
                Text(
                    String(
                        format: "%.1f GB / %.0f GB",
                        state.stats.availableMemoryGB,
                        state.stats.totalMemoryGB))
            }
            .font(.system(.body, design: .monospaced))

            HStack {
                Text("CPU:")
                Spacer()
                Text(String(format: "%.1f%%", state.stats.cpuUsagePercent))
            }
            .font(.system(.body, design: .monospaced))
        }
    }

    private var buildsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(".NET Builds (\(state.builds.count))")
                .font(.headline)

            if state.builds.isEmpty {
                Text("No active builds")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(state.builds.filter { $0.kind != .msbuildWorker }) { build in
                    HStack {
                        Image(
                            systemName: build.kind == .vbcsCompiler
                                ? "server.rack" : "hammer")
                        Text(build.displayName)
                        Spacer()
                        Text(formatResources(cpu: build.cpuPercent, mem: build.memoryGB))
                            .foregroundStyle(.secondary)
                    }
                }

                let workers = state.builds.filter({ $0.kind == .msbuildWorker })
                let workerCount = workers.count
                if workerCount > 0 {
                    let totalCpu = workers.reduce(0.0) { $0 + $1.cpuPercent }
                    let totalMem = workers.reduce(0.0) { $0 + $1.memoryGB }
                    HStack {
                        Image(systemName: "gearshape.2")
                        Text("MSBuild workers (\(workerCount))")
                        Spacer()
                        Text(formatResources(cpu: totalCpu, mem: totalMem))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func formatResources(cpu: Double, mem: Double) -> String {
        "\(String(format: "%.0f%%", cpu)) · \(String(format: "%.1f", mem))G"
    }
}
