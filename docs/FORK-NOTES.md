# Fork notes

This repository is a fork of [pluk-inc/markdown-preview](https://github.com/pluk-inc/markdown-preview),
maintained by [inquinity](https://github.com/inquinity). It exists for one reason:

> **The upstream app makes outbound network connections that are not acceptable on a
> corporate network.** This fork removes them. It does not add features.

Everything else — reading, printing, PDF export, Quick Look — is upstream's work and
should stay upstream's work.

## Relationship to upstream

| Remote | URL | Role |
|---|---|---|
| `origin` | `inquinity/markdown-preview` | This fork. Where our `main` lives. |
| `upstream` | `pluk-inc/markdown-preview` | The base project. Read-only; never pushed to. |

Upstream is actively maintained (142 commits in the two months before this fork was
cut), so staying close to it is worth real effort. Every change here is shaped to keep
merges cheap.

## What upstream sends over the network

Recorded here because it is the whole reason for the fork:

| Component | Destination | Default |
|---|---|---|
| Sentry crash reporting | `sentry.io` (org `pluk-inc`) | **on** |
| PostHog usage analytics | `us.i.posthog.com` | **on** — opt-out, not opt-in |
| Sparkle auto-updater | `release.md-preview.app` | **on**, automatic checks |

None of these are wrong for a consumer app. They are simply incompatible with our use.

## Branch model

```
upstream/main          remote-tracking only; never a local branch we edit
main         (origin)  our product line: upstream + our changes
fork/<topic>           short-lived; merged with --no-ff, then deleted
contrib/<topic>        cut from upstream/main; ONE fix each; for PRs to pluk-inc
```

`contrib/*` branches are cut fresh from `upstream/main` and contain only the fix being
offered — never our deprivileging — so the PR diff is exactly what upstream is being
asked to review.

### Syncing with upstream

```bash
./scripts/check-upstream.sh          # read-only: has upstream moved?
git fetch upstream
git merge upstream/main              # merge, never rebase
```

**Merge, never rebase.** `main` is published and others may build from it; rebasing
means force-pushing over history they hold. `git rerere` is enabled in this clone so
each conflict resolution is recorded once and replayed on later merges — if you clone
fresh, re-enable it:

```bash
git config rerere.enabled true
git config rerere.autoupdate true
```

### Merge commit convention

Two kinds of merge land on `main`. Prefix them so the audit trail stays readable:

```
Fork: remove Sentry and PostHog telemetry
Sync: upstream/main @ a1b2c3d
```

`git log --merges --grep='^Fork:'` is then a complete changelog of everything we have
done to the base project.

### Reviewing what this fork changes

```bash
./scripts/show-private-changes.sh --stat     # summary
./scripts/show-private-changes.sh            # full diff
./scripts/show-private-changes.sh --commits  # commit log
```

This is the authoritative answer, independent of branch structure. Both scripts are
ported from the maintainer's earlier fork of MDviewer.

## How changes are applied

Upstream churns `md-preview/App/AppDelegate.swift` (1,276 lines) and
`md-preview/Features/Settings/SettingsModel.swift` heavily. A naive removal would edit
both in six places and conflict on every sync. So each change picks the approach with
the smallest permanent conflict surface:

| Component | Approach | Why |
|---|---|---|
| Sentry | **Stub** — keep `CrashReporter.swift` and its `isEnabled` / `start()` signatures, drop `import Sentry`, empty the bodies | All four `AppDelegate` call sites and three `SettingsModel` call sites keep compiling untouched |
| PostHog | **Stub** — same for `UsageAnalyticsReporter`; `isEnabled` returns `false`, writes ignored | Same |
| CLI installer | **Orphan** — remove only the menu item registration and the entitlements; leave the now-unreachable installer code in place | Costs one line instead of four blocks in `AppDelegate` |
| Sparkle | **Excise** | `SPUStandardUpdaterController` / `SPUUpdater` are concrete types with KVO observers bound to them; faking them is more fragile than deleting. The plist keys and `mach-lookup` entitlements have to change regardless. |

**There is deliberately dead code in this fork.** The CLI installer in `AppDelegate.swift`
and the emptied reporter bodies are intentional — they are load-bearing for cheap merges,
not oversights. Do not "clean them up."

The same logic gives the general rule:

> **New files are free. Edits to upstream-maintained files are rent.**

Prefer adding a new file over editing an existing one. That is why the internal install
guide lives in `docs/INTERNAL-INSTALL.md` rather than in `README.md`.

## Upstream contribution track

Not everything here is fork-only. Genuine hardening goes back to upstream, because once
merged it stops being our diff to carry:

| Finding | Form | Status |
|---|---|---|
| `md-asset:` scheme has no path containment (`MarkdownAssetResolution.swift:49`) | Private security advisory | **filed 2026-09-02** — [GHSA-vgmc-h5g6-xh2q](https://github.com/pluk-inc/markdown-preview/security/advisories/GHSA-vgmc-h5g6-xh2q), state `triage` |
| Preview document has no Content-Security-Policy | Issue → PR | drafted, held pending upstream's response to the advisory |
| `ALLOWED_URI_REGEXP` permits `http`/`https` | Issue → PR, after the CSP lands | pending |

The `md-asset:` finding goes through GitHub's private vulnerability reporting (enabled
on upstream), **not** a public issue: it describes an unfixed weakness in a shipping app
with real users.

Nothing about removing telemetry, Sparkle, or the CLI installer is offered upstream.
Those are product decisions, not defects, and filing them would be noise.

## Roadmap

| # | Milestone | Contents | Status |
|---|---|---|---|
| **M0** | Repo setup | Remotes, `rerere`, tracking scripts, this document, FORK STATUS blocks | ✅ done |
| **M1** | Upstream contributions | Advisory + CSP issue/PR + URI allowlist issue/PR | **in progress** — advisory filed |
| **M2** | Identity & release | Team ID, four bundle IDs, app group, display names; replace the Amore release pipeline; rewrite `CLAUDE.md` / `AGENTS.md` | pending |
| **M3** | Deprivileging | Stub Sentry + PostHog; excise Sparkle; orphan CLI installer; collapse Privacy pane; drop `network.client` and test Quick Look | pending |
| **M3b** | *Conditional* | Quick Look CSP, if dropping `network.client` regresses the extension | pending |
| **M4** | Containment | `md-asset:` confinement — **skipped entirely if upstream accepts the M1 advisory** | pending |
| **M5** | Distribution | Notarize, verify on a second Mac, ship via corporate share or Dropbox | pending |
| **F1** | *Future* | Private Homebrew tap (`inquinity/homebrew-tap`) | — |
| **F2** | *Future* | Full CSP on the main preview page | — |
| **F3** | *Future* | Security-scoped bookmarks; drop the `/` read-only entitlement | — |

### Deferred, with reasons

**F2 — CSP on the main preview page.** The page relies on inline scripts for the host
bridge, morphdom wiring and theming, so the policy needs `'unsafe-inline'` and careful
testing against KaTeX, Mermaid, highlight.js and the copy-button bridge. A CSP violation
shows up as a silently unrendered element, not a crash. Deferred until the fork is
otherwise stable. If upstream accepts the M1 CSP PR, this arrives for free.

**F3 — the `/` read-only entitlement.** Both targets carry
`com.apple.security.temporary-exception.files.absolute-path.read-only` = `/`. There is no
security-scoped bookmark machinery anywhere in the codebase — the entitlement *is* the
access strategy for the project navigator and relative-asset resolution. Replacing it
means implementing bookmark persistence and an access lifecycle, which is a week of work
on someone else's architecture. Once M4 (or upstream's fix) confines the `md-asset:`
scheme, the WebView-reachable surface is closed and only the app's own code holds broad
read, which is a much smaller concern for a read-only entitlement.

## Distribution

No Sparkle means no automatic updates: new builds are handed out manually via the
corporate share or Dropbox. See `docs/INTERNAL-INSTALL.md` for what recipients need to do
— in particular, Quick Look does not register until the app has been moved to
`/Applications` and launched once.

## License

Upstream is MIT and this fork remains MIT. `LICENSE` is unmodified and upstream's
copyright notice stays intact.

---

*Fork cut 2026-09-01 from upstream `f8c22d0`.*
