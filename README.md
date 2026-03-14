# status-bar

Personal macOS menu bar app built with SwiftUI.

## Project Structure

- **StatusBar** — SwiftUI app entry point (`MenuBarExtra`)
- **StatusBarKit** — Core logic library (testable)
- **StatusBarKitTests** — Unit tests for StatusBarKit

## Build & Run

```bash
# Build
swift build

# Run tests
swift test
```

Or open `Package.swift` in Xcode and run the `StatusBar` target.

## Requirements

- macOS 14+
- Swift 6.0+
