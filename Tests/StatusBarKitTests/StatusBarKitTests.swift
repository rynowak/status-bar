import Testing
@testable import StatusBarKit

// MARK: - BuildMonitor.classify

@Test func classifyDotnetBuild() {
    let kind = BuildMonitor.classify(arguments: [
        "/usr/local/share/dotnet/dotnet", "build", "MyProject.csproj",
    ])
    #expect(kind == .dotnetBuild)
}

@Test func classifyDotnetMSBuild() {
    let kind = BuildMonitor.classify(arguments: [
        "/usr/local/share/dotnet/dotnet", "msbuild", "MyProject.csproj",
    ])
    #expect(kind == .dotnetMSBuild)
}

@Test func classifyVBCSCompiler() {
    let kind = BuildMonitor.classify(arguments: [
        "/usr/local/share/dotnet/dotnet",
        "exec",
        "/usr/local/share/dotnet/sdk/8.0.100/Roslyn/bincore/VBCSCompiler.dll",
        "-pipename:abc123",
    ])
    #expect(kind == .vbcsCompiler)
}

@Test func classifyMSBuildWorker() {
    let kind = BuildMonitor.classify(arguments: [
        "/usr/local/share/dotnet/dotnet",
        "/usr/local/share/dotnet/sdk/10.0.201/MSBuild.dll",
        "/noautoresponse", "/nologo", "/nodemode:1",
    ])
    #expect(kind == .msbuildWorker)
}

@Test func classifyNonBuildReturnsNil() {
    let kind = BuildMonitor.classify(arguments: [
        "/usr/local/share/dotnet/dotnet", "run",
    ])
    #expect(kind == nil)
}

@Test func classifyEmptyArgsReturnsNil() {
    let kind = BuildMonitor.classify(arguments: [])
    #expect(kind == nil)
}

// MARK: - BuildMonitor.extractProjectName

@Test func extractProjectNameCsproj() {
    let name = BuildMonitor.extractProjectName(from: [
        "/usr/local/share/dotnet/dotnet", "build",
        "/Users/dev/MyProject/MyProject.csproj",
    ])
    #expect(name == "MyProject.csproj")
}

@Test func extractProjectNameSln() {
    let name = BuildMonitor.extractProjectName(from: [
        "/usr/local/share/dotnet/dotnet", "build", "/Users/dev/MySolution.sln",
    ])
    #expect(name == "MySolution.sln")
}

@Test func extractProjectNameFsproj() {
    let name = BuildMonitor.extractProjectName(from: [
        "/usr/local/share/dotnet/dotnet", "build",
        "/Users/dev/MyFSharp.fsproj",
    ])
    #expect(name == "MyFSharp.fsproj")
}

@Test func extractProjectNameNone() {
    let name = BuildMonitor.extractProjectName(from: [
        "/usr/local/share/dotnet/dotnet", "build",
    ])
    #expect(name == nil)
}

// MARK: - SystemMonitor.cpuUsage

@Test func cpuUsageCalculation() {
    let prev = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
    let curr = CPUTicks(user: 200, system: 100, idle: 1700, nice: 0)
    // Active delta: 300 - 150 = 150, Total delta: 2000 - 1000 = 1000
    let usage = SystemMonitor.cpuUsage(previous: prev, current: curr)
    #expect(abs(usage - 15.0) < 0.01)
}

@Test func cpuUsageZeroDelta() {
    let ticks = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
    let usage = SystemMonitor.cpuUsage(previous: ticks, current: ticks)
    #expect(usage == 0)
}

@Test func cpuUsageCappedAt100() {
    let prev = CPUTicks(user: 0, system: 0, idle: 1000, nice: 0)
    let curr = CPUTicks(user: 500, system: 500, idle: 1000, nice: 0)
    let usage = SystemMonitor.cpuUsage(previous: prev, current: curr)
    #expect(usage == 100.0)
}

// MARK: - SystemMonitor.getMemoryStats (integration)

@Test func memoryStatsReturnNonZero() {
    let (available, total) = SystemMonitor.getMemoryStats()
    #expect(total > 0)
    #expect(available > 0)
    #expect(available <= total)
}
