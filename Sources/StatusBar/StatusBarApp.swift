import SwiftUI
import StatusBarKit

@main
struct StatusBarApp: App {
    @State private var state = MonitorState()

    var body: some Scene {
        MenuBarExtra {
            ContentView(state: state)
        } label: {
            Text(state.menuBarText)
        }
        .menuBarExtraStyle(.window)
    }
}
