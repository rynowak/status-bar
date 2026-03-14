import SwiftUI

@main
struct StatusBarApp: App {
    var body: some Scene {
        MenuBarExtra("Status Bar", systemImage: "menubar.rectangle") {
            ContentView()
        }
    }
}
