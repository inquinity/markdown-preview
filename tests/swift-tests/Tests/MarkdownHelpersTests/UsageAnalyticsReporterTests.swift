import Foundation
import XCTest
@testable import MarkdownHelpers

/// Guards the fork's central promise: this build reports nothing.
///
/// Upstream's tests here covered the PostHog request construction, the
/// once-per-UTC-day capture limit and the installation ID. All of that is gone,
/// replaced by a stub. These tests exist so that if an upstream merge ever
/// reintroduces the real reporter, the suite fails loudly instead of silently
/// restoring telemetry. See docs/FORK-NOTES.md.
final class UsageAnalyticsReporterTests: XCTestCase {

    func testAnalyticsIsDisabled() {
        XCTAssertFalse(
            UsageAnalyticsReporter.isEnabled,
            "Analytics must stay off. Upstream defaults this to true when the "
                + "preference is unset; if this fails, a merge has restored it."
        )
    }

    func testEnablingAnalyticsIsRefused() {
        UsageAnalyticsReporter.isEnabled = true
        XCTAssertFalse(
            UsageAnalyticsReporter.isEnabled,
            "The setter must discard writes. A settable stub keeps the Settings "
                + "binding compiling without giving it anything to turn on."
        )
    }

    func testRecordingAnEventDoesNothing() {
        // No assertion beyond "this returns without attempting a request".
        // The real guarantee is structural: the app ships without
        // com.apple.security.network.client, so the sandbox refuses outbound
        // connections even if code tries.
        UsageAnalyticsReporter.recordAppBecameActive()
    }
}
