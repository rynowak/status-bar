# Status Bar

Personal macOS menu bar app for monitoring system resources and .NET build activity.

## What It Does

- **Menu bar** — shows available RAM, CPU % (when ≥10%), and active .NET build count
- **Detail view** — click to see system stats, active `dotnet build` / `msbuild` commands, VBCSCompiler processes, and MSBuild worker counts with aggregated CPU % and memory
- **Launch at Login** — toggle in the detail view via SMAppService

## Install

### From DMG

Download `StatusBar.dmg` from the latest [CI run](../../actions), open it, and drag `Status Bar` to Applications.

### From Source

```bash
# Build and install to /Applications
make install

# Or just build the DMG
make dmg
# Output: .build/StatusBar.dmg
```

### Uninstall

```bash
make uninstall
```

## Development

```bash
# Build
swift build

# Run tests
swift test

# Run locally (debug)
swift build && .build/debug/StatusBar
```

Or open `Package.swift` in Xcode and run the `StatusBar` target.

## Project Structure

- **StatusBar** — SwiftUI app with `MenuBarExtra`, detail view, launch-at-login toggle
- **StatusBarKit** — Core logic library (testable without UI)
  - `SystemMonitor` — CPU and memory stats via Mach kernel APIs
  - `BuildMonitor` — process table scanning for dotnet/VBCSCompiler/MSBuild workers
  - `MonitorState` — observable model combining both monitors, polling every 1 second
- **StatusBarKitTests** — Unit tests

## Requirements

- macOS 14+
- Swift 6.0+
