import AppKit
import SwiftUI
import StatusBarKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: MonitorState!
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var visibilityObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        state = MonitorState()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView(state: state))

        scheduleUpdate()

        // Force the item visible if the system or user hides it.
        visibilityObservation = statusItem.observe(\.isVisible, options: [.new]) {
            [weak self] _, change in
            if change.newValue == false {
                Task { @MainActor [weak self] in self?.statusItem.isVisible = true }
            }
        }
    }

    private func scheduleUpdate() {
        withObservationTracking {
            statusItem.button?.title = state.menuBarText

            let projects = state.composeProjects
            let composeHealthy = projects.filter(\.isHealthy).count
            let stats = state.stats
            let usedGB = stats.totalMemoryGB - stats.availableMemoryGB
            let memFraction = stats.totalMemoryGB > 0
                ? usedGB / stats.totalMemoryGB : 0
            let view = MenuBarGraphicsView(
                cpuHistory: state.cpuHistory,
                cpuPercent: stats.cpuUsagePercent,
                memFraction: memFraction,
                memUsedGB: usedGB,
                composeHealthy: composeHealthy,
                composeTotal: projects.count,
                showSystemStats: state.showSystemStats,
                showGraphics: state.showMenuBarGraphics)
            let renderer = ImageRenderer(content: view)
            renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
            statusItem.button?.image = nil
            if let cgImage = renderer.cgImage {
                let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                let size = NSSize(
                    width: CGFloat(cgImage.width) / scale,
                    height: CGFloat(cgImage.height) / scale)
                let image = NSImage(cgImage: cgImage, size: size)
                image.isTemplate = false
                statusItem.button?.image = image
                statusItem.button?.imagePosition = .imageLeading
            }
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.scheduleUpdate() }
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
