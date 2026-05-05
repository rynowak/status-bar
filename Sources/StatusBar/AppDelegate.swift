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

        statusItem = NSStatusBar.system.statusItem(withLength: 160)
        if let button = statusItem.button {
            button.alignment = .right
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
