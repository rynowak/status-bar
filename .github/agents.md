# Status Bar - Agent Instructions

## Project Overview

A personal macOS menu bar app that monitors system resources (CPU, RAM) and .NET build activity (dotnet build, msbuild, VBCSCompiler). Built with Swift 6, SwiftUI, and Swift Package Manager.

## Architecture

- **StatusBar** (`Sources/StatusBar/`) — SwiftUI app target. Uses `MenuBarExtra` with `.window` style for the detail popover. Entry point is `StatusBarApp.swift`.
- **StatusBarKit** (`Sources/StatusBarKit/`) — Library target with all monitoring logic. No UI dependencies. This is where new features and data sources should be added.
  - `SystemMonitor` — CPU ticks via `host_processor_info`, memory via `host_statistics64`. Stateless functions.
  - `BuildMonitor` — Scans the process table via `sysctl` for `dotnet` and `VBCSCompiler` processes. Reads command-line args via `KERN_PROCARGS2`. Classifies processes by kind.
  - `MonitorState` — `@Observable` `@MainActor` class that combines both monitors. Polls every 1 second. Tracks CPU time deltas per-process to compute CPU %. This is the main model the UI binds to.
- **StatusBarKitTests** (`Tests/StatusBarKitTests/`) — Unit tests using swift-testing framework.

## Build & Test

```bash
swift build          # debug build
swift build -c release  # release build
swift test           # run tests
make bundle          # build .app bundle with ad-hoc codesign
make dmg             # build DMG installer
make install         # copy .app to /Applications
make uninstall       # remove from /Applications
```

## Key Conventions

- All monitoring logic goes in **StatusBarKit**, not the app target. Keep it testable.
- Use Mach/Darwin APIs directly — don't shell out to `ps`, `top`, etc.
- The menu bar label should stay compact. Hide indicators when they're not informative (e.g., CPU <10%, no active builds).
- Use `.monospacedDigit()` on menu bar text to prevent layout shifts.
- `Info.plist` has `LSUIElement = true` — the app has no Dock icon.
- Ad-hoc code signing (`codesign --force --sign -`) is used for the bundle. No Apple Developer account required.

## Adding New Monitors

To add a new data source (e.g., Docker containers, Xcode builds):

1. Create a new file in `Sources/StatusBarKit/` with a static monitor type (e.g., `DockerMonitor`)
2. Add relevant data to `MonitorState` — new `@Published` property, update `refresh()`
3. Update the compact label in `MonitorState.compactLabel` if it should appear in the menu bar
4. Add a new section in `ContentView` for the detail view
5. Add tests in `Tests/StatusBarKitTests/`

## Process Detection

The `BuildMonitor` identifies processes by:
1. Scanning all processes via `sysctl KERN_PROC_ALL`
2. Filtering by process name (`dotnet`, `VBCSCompiler`)
3. Reading command-line args via `sysctl KERN_PROCARGS2`
4. Classifying by the second argument: `build` → dotnet build, `msbuild` → dotnet msbuild, `MSBuild.dll` → MSBuild worker, `VBCSCompiler` in any arg → VBCSCompiler
5. Extracting project names from `.csproj`/`.fsproj`/`.vbproj`/`.sln` args
