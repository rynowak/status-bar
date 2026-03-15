import Testing
@testable import StatusBarKit

@Test func greetingReturnsExpectedMessage() {
    let result = StatusBarKit.greeting()
    #expect(result == "Hello from StatusBarKit!")
}
