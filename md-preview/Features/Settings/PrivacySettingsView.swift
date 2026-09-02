//
//  PrivacySettingsView.swift
//  md-preview
//

import SwiftUI

// MARK: - Privacy

/// Upstream offers two toggles here: anonymous crash reports to Sentry, and
/// anonymous usage analytics to PostHog. This fork ships neither, and neither
/// does it ship Sparkle, so there is nothing to turn on or off — the pane
/// states the guarantee instead.
///
/// The pane is kept rather than removed so `SettingsWindowController`'s tab
/// list is untouched. See docs/FORK-NOTES.md.
struct PrivacySettingsView: View {

    var body: some View {
        Form {
            Section {
                LabeledContent(L("Network activity")) {
                    Text(L("None")).foregroundStyle(.secondary)
                }
            } footer: {
                Text(L("This build makes no network connections. Crash reporting, usage analytics and automatic updates have all been removed, and the app is not granted the sandbox entitlement that would allow outbound connections — so it cannot contact anything even if a future change tried to."))
            }

            Section {
                LabeledContent(L("Remote images")) {
                    Text(L("Loaded")).foregroundStyle(.secondary)
                }
            } footer: {
                Text(L("A Markdown document that references an image by http or https URL will still load it when previewed, which tells that server the document was opened. Only the app itself is silent."))
            }
        }
        .formStyle(.grouped)
    }
}
