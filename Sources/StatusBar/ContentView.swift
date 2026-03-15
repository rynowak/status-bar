import SwiftUI
import StatusBarKit

struct ContentView: View {
    let state: MonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            systemSection
            Divider()
            buildsSection
            Divider()
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
                ForEach(state.builds) { build in
                    HStack {
                        Image(
                            systemName: build.kind == .vbcsCompiler
                                ? "server.rack" : "hammer")
                        Text(build.displayName)
                        Spacer()
                        Text("PID \(build.pid)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
