import SwiftUI
import StatusBarKit

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status Bar")
                .font(.headline)

            Divider()

            Text(StatusBarKit.greeting())

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 200)
    }
}
