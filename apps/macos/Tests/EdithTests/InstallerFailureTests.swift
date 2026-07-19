import Testing

@testable import EdithInstaller

@Suite struct InstallerFailureTests {
    @Test func distinguishesRetryableDownloadFailures() {
        #expect(InstallerFailure.network.title == "Download interrupted")
        #expect(InstallerFailure.network.message == "Check your connection and try again.")
        #expect(InstallerFailure.serverUnavailable.title == "Download unavailable")
        #expect(InstallerFailure.serverUnavailable.message.contains("502"))
    }
}
