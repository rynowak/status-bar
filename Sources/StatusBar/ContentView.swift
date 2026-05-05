import SwiftUI
import ServiceManagement
import StatusBarKit

struct ContentView: View {
    @Bindable var state: MonitorState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if state.showSystemStats {
                systemSection
            }

            Divider()
            monetSection

            if !state.builds.isEmpty || !state.vsCodeProcesses.isEmpty {
                Divider()
                dotNetSection
            }

            Divider()
            HStack(spacing: 12) {
                Toggle("System Stats", isOn: $state.showSystemStats)
                Toggle("Graphs", isOn: $state.showMenuBarGraphics)
                Toggle("Login", isOn: $launchAtLogin)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("System")
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                cpuChart
                memoryGauge
            }
        }
    }

    private var cpuChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("CPU")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", state.stats.cpuUsagePercent))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let barWidth: CGFloat = 3
                let spacing: CGFloat = 1
                let maxBars = Int(geo.size.width / (barWidth + spacing))
                let samples = Array(state.cpuHistory.suffix(maxBars))

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(samples.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color.green)
                            .frame(
                                width: barWidth,
                                height: max(1, geo.size.height * CGFloat(value) / 100.0))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(height: 48)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.secondary.opacity(0.3))
            )
        }
    }

    private var memoryGauge: some View {
        let usedGB = state.stats.totalMemoryGB - state.stats.availableMemoryGB
        let fraction = state.stats.totalMemoryGB > 0
            ? usedGB / state.stats.totalMemoryGB : 0

        return VStack(spacing: 4) {
            Text("MEM")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.secondary.opacity(0.3))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green)
                        .frame(height: geo.size.height * CGFloat(fraction))
                }
            }
            .frame(width: 28, height: 48)

            Text(String(format: "%.0f/%.0fG", usedGB, state.stats.totalMemoryGB))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var monetSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Monet Instances")
                .font(.headline)

            ForEach(state.composeProjects) { project in
                DisclosureGroup {
                    let columns = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                        ForEach(project.activeServices) { service in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(service.isRunning ? .green : .red)
                                    .frame(width: 6, height: 6)
                                Text(service.service)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.top, 2)
                    .padding(.leading, 16)
                } label: {
                    HStack {
                        Circle()
                            .fill(project.isHealthy ? .green : .yellow)
                            .frame(width: 8, height: 8)
                        Text(project.name)
                        Spacer()
                        Text("\(project.runningCount)/\(project.activeCount)")
                            .foregroundStyle(.secondary)
                        Button {
                            state.killComposeProject(project: project.name)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(state.killingProjects.contains(project.name))
                    }
                }
            }
        }
    }

    private var dotNetSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            let totalCount = state.builds.count + state.vsCodeProcesses.count
            Text(".NET (\(totalCount))")
                .font(.headline)

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

            ForEach(state.vsCodeProcesses) { process in
                HStack {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                    Text(process.displayName)
                    Spacer()
                    Text(formatResources(cpu: process.cpuPercent, mem: process.memoryGB))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func formatResources(cpu: Double, mem: Double) -> String {
        "\(String(format: "%.0f%%", cpu)) · \(String(format: "%.1f", mem))G"
    }
}

struct MenuBarGraphicsView: View {
    let cpuHistory: [Double]
    let cpuPercent: Double
    let memFraction: Double
    let memUsedGB: Double
    let composeHealthy: Int
    let composeTotal: Int
    let showSystemStats: Bool
    let showGraphics: Bool

    private let maxBars = 15
    private let barWidth: CGFloat = 1.5
    private let barSpacing: CGFloat = 0.5
    private let chartHeight: CGFloat = 13

    var body: some View {
        HStack(spacing: 1) {
            composeIndicator
                .padding(.trailing, showSystemStats ? 2 : 0)

            if showSystemStats && showGraphics {
                verticalLabel("CPU")

                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(0..<maxBars, id: \.self) { i in
                        let samples = paddedCPUSamples
                        RoundedRectangle(cornerRadius: 0.25)
                            .fill(samples[i] > 0 ? Color.green : Color.clear)
                            .frame(
                                width: barWidth,
                                height: max(0.5, chartHeight * CGFloat(samples[i]) / 100.0))
                    }
                }
                .frame(
                    width: CGFloat(maxBars) * (barWidth + barSpacing),
                    height: chartHeight,
                    alignment: .bottomLeading)
                .padding(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )

                Text(String(format: "%3.0f%%", cpuPercent))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 30, alignment: .trailing)
                    .padding(.trailing, 3)

                verticalLabel("MEM")

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                        .frame(width: 10, height: chartHeight + 4)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.green)
                        .frame(
                            width: 8,
                            height: max(1, (chartHeight + 2) * CGFloat(memFraction)))
                        .padding(.bottom, 1)
                }
                .frame(width: 10, height: chartHeight + 4)

                Text(String(format: "%3.0fG", memUsedGB))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }

    private var composeIndicator: some View {
        let hasProjects = composeTotal > 0
        let isHealthy = hasProjects && composeHealthy == composeTotal
        let statusColor: Color = hasProjects
            ? (isHealthy ? .green : .yellow)
            : .gray

        return HStack(spacing: 1) {
            if let url = Bundle.module.url(forResource: "monet-icon", withExtension: "png"),
               let icon = NSImage(contentsOf: url) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 16, height: 16)
            }
            Text("\(composeTotal)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(statusColor)
                .fixedSize()
        }
    }

    private var paddedCPUSamples: [Double] {
        let recent = Array(cpuHistory.suffix(maxBars))
        return Array(repeating: 0.0, count: max(0, maxBars - recent.count)) + recent
    }

    private func verticalLabel(_ text: String) -> some View {
        let fontSize: CGFloat = text.count <= 3 ? 6 : 5
        let spacing: CGFloat = text.count <= 3 ? -0.5 : -1
        return VStack(spacing: spacing) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, char in
                Text(String(char))
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}
