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

| Component | Destination | Upstream default | Here |
|---|---|---|---|
| Sentry crash reporting | `sentry.io` (org `pluk-inc`) | on | stubbed |
| PostHog usage analytics | `us.i.posthog.com` | on — opt-out, not opt-in | stubbed |
| Sparkle auto-updater | `release.md-preview.app` | on, automatic checks | excised |

None of these are wrong for a consumer app. They are simply incompatible with
our use.

**The guarantee is that the code is gone — not that the sandbox forbids it.**

An earlier version of this document claimed both. That was wrong, and the
correction matters: `com.apple.security.network.client` was removed from both
targets in M3, and **both surfaces rendered blank**. A sandboxed app cannot
complete a WKWebView load without that entitlement. It is not about `md-asset:`
subresources — the Quick Look extension inlines everything and failed the same
way — WebKit routes every resource load through its networking process, and the
sandbox gates that on this entitlement.

So the entitlement is back on both targets and cannot be removed. What holds:

| Claim | Enforced by |
|---|---|
| The app never contacts a server on its own | The code is gone — see the stubbed reporters and the excised updater, guarded by `ForkPostureTests` |
| A previewed document cannot phone home in Quick Look | `QuickLookContentPolicy`, a CSP in the page |
| A previewed document cannot phone home in the app window or the editor | `PreviewContentPolicy`, a CSP in the page |

Verify empirically rather than by reading entitlements, which is what misled us:

```bash
sudo lsof -i -a -p $(pgrep -f "MDView") -r 2
```

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
| `md-asset:` scheme has no path containment (`MarkdownAssetResolution.swift:49`) | Advisory → PR | **accepted**; [GHSA-vgmc-h5g6-xh2q](https://github.com/pluk-inc/markdown-preview/security/advisories/GHSA-vgmc-h5g6-xh2q). Maintainer asked us to write the fix — [PR #337](https://github.com/pluk-inc/markdown-preview/pull/337) open, awaiting review |
| Preview document has no Content-Security-Policy | Issue → PR | **filed** — [#339](https://github.com/pluk-inc/markdown-preview/issues/339), with both working policies and an offer to PR |
| `ALLOWED_URI_REGEXP` permits `http`/`https` | Issue → PR, after the CSP lands | pending |
| Mermaid diagrams do not render in Quick Look, though `README.md` says they do | Issue | **filed** — [#338](https://github.com/pluk-inc/markdown-preview/issues/338), against cask 0.0.51 |

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
| **M2** | Identity & release | Team ID, four bundle IDs, app group, display names; replace the Amore release pipeline; rewrite `CLAUDE.md` / `AGENTS.md` | ✅ done |
| **M3** | Deprivileging | Stub Sentry + PostHog; excise Sparkle; orphan CLI installer; collapse Privacy pane; drop `network.client` and test Quick Look | ✅ done |
| **M3b** | *Conditional* | Quick Look CSP — the extension does need `network.client`, so the page blocks remote content instead | ✅ done |
| **M4** | Containment | `md-asset:` confinement — written and submitted upstream as [PR #337](https://github.com/pluk-inc/markdown-preview/pull/337); arrives here on the next `git merge upstream/main` once merged | **waiting on upstream** — see below |
| **M2b** | Rebranding | Replace the app icon | ✅ done — placeholder, regenerate with `scripts/make-icon.swift` |
| **M5** | Distribution | Notarize (✅ `dist/MDView 1.0.0.dmg`), verify on a second Mac (✅ passed), ship via corporate share or Dropbox (pending — the user's own action, not tool-driven) | **in progress** — one step left |

## Backlog

Unscheduled — not part of the milestone sequence above, and not blocking M5. `B1` (Mermaid in Quick Look) isn't listed here: it's an upstream bug, tracked in the Upstream contribution track table above rather than duplicated.

| # | Item | Notes |
|---|---|---|
| **F1** | Private Homebrew tap (`inquinity/homebrew-tap`) | Explicitly *not* part of M5 — M5 ships by corporate share / Dropbox. A tap is a separate, later distribution channel. |
| **F2** | CSP on the app preview page and editor (`PreviewContentPolicy`) | ✅ done and verified — math and editing confirmed working after the CSP landed. |
| **F3** | Security-scoped bookmarks; drop the `/` read-only entitlement | |
| **F4** | Click-to-load control for remote images in the app window, the way mail clients defer them | |
| **F5** | Manual-test `.md` files need pass/fail criteria a human can read off the screen | See below |
| **F7** | Application menu still said "Markdown Preview" | ✅ done — see below. Its two adjacent findings ("Check for Updates…", "Send Anonymous Crash Reports") are also resolved — both removed from the menu on request, see below. |
| **F8** | Pick a final product name and icon | Both current ones are explicitly provisional: `MDView` was a quick pick to stop the Dock collision with upstream, and the icon (`scripts/make-icon.swift`) was called a placeholder when it shipped. Whatever gets decided needs to land in `Localizable.strings` *and* `MainMenu.strings` (see F7) *and* `AppIcon.icon`, not just one of them. |

### Deferred, with reasons

**F2 — CSP on the app preview page and editor. Implemented as
`md-preview/Rendering/PreviewContentPolicy.swift`.** With
`com.apple.security.network.client` proven un-removable, this is the control that stops a
document reaching the network, not the sandbox.

Applied at all three `loadHTMLString` sites in `MarkdownWebView` and at the editor's, so
reading and editing are both covered. Kept separate from `QuickLookContentPolicy` on
purpose: that page inlines its vendor bundles and carries images as `data:`/`cid:`, while
this one fetches scripts and images over `md-asset:`. One shared policy would have to
permit the union, which is weaker than either.

`'unsafe-inline'` is unavoidable for scripts and styles — the host bridge, the DOMPurify
bootstrap, the theme injection and CodeMirror are all emitted inline. `script-src
md-asset:` is required because the reader lazy-loads KaTeX, highlight.js and Mermaid over
the scheme after first paint; the handler serves only an allow-listed set of bundled
files, so it is narrower than it appears. `font-src data:` covers the bundled KaTeX CSS,
which carries its fonts as base64.

**A CSP fails silently** — a blocked resource is an unrendered element, not an error, so
unit tests pinning the policy string cannot tell you the page still looks right. **Verified
by eye**: math renders and editing works in the app window with the policy applied.
Diagrams were not part of that check — Mermaid was separately found not to render in
Quick Look at all (B1, an upstream bug), and its status in the app window under this CSP
has not been explicitly confirmed either way.

**M2b — the app icon. Done, with a placeholder.** The fork shipped upstream's icon, so two
identically named and identically iconed apps sat in the Dock — and upstream has an open
issue that their icon is too close to macOS Preview's.

`md-preview/AppIcon.icon` is an Icon Composer document: an `icon.json` manifest plus one
PNG layer in `Assets/`. The layer is now `AppIconLayer.png`, drawn on transparency so
Icon Composer still supplies the background gradient and glass treatment. `scale` moved
from `0.82` to `1.0`: upstream's layer was a full-bleed image needing inset, this one
carries its own.

**It is a placeholder, not a design.** Amber, chosen to sit far from macOS Preview's
blue-grey, with the Markdown down-arrow, and legible at 16px in a Finder list.
`scripts/make-icon.swift` regenerates it, so colour and mark are cheap to change —
replace the PNG and rebuild. Real artwork can drop in the same way.

`docs/app-icon.png` and the README screenshots are upstream marketing assets and are left
alone.

The product is also renamed: **MDView**, so it no longer collides with an upstream
install in the Dock, in Finder, or in the list of running apps. `PRODUCT_NAME` carries it
(`MDView (Dev)` for Debug), and the display name in `Localizable.strings` follows — values
only, since the keys are the identifiers `L()` looks up.

**The bundle identifier deliberately still says `markdown-preview`**
(`com.altmansoftwaredesign.markdown-preview`). Renaming it again would mean a new app
group, discarded preferences and another LaunchServices re-registration, all for a string
no user sees. The mismatch is intentional; do not "tidy" it.

**F4 — click-to-load remote images in the app window.** Quick Look blocks remote images
outright (M3b), and that is the right default for a surface reached by pressing space on
a file you may not have chosen. The app window is a deliberate act, so the eventual
answer there is the one mail clients settled on: don't load remote content, show a bar
offering to. Deferred because it needs UI, a per-document decision, and somewhere to
remember it — it is a feature, not a security prerequisite. F2 (a blanket CSP for that
page) is the cruder version that could land first.

**M4 — `md-asset:` containment: written, submitted upstream, deliberately not carried here
yet.** The fix exists as [PR #337](https://github.com/pluk-inc/markdown-preview/pull/337)
against upstream, not on this fork's `main`. So the shipped MDView build still resolves
`md-asset:` paths without a containment check, and a document could name any file the
user can read.

**This is a considered decision, not an oversight.** The maintainer accepted the advisory
and asked us to write the fix; the tidiest outcome is inheriting it through a normal
`git merge upstream/main` with zero fork-local diff, rather than carrying a patch that
later has to be reconciled with whatever shape upstream merges. The risk of waiting was
judged acceptable because this build is used to read documents its own user authored —
the exposure needs untrusted Markdown, and there isn't any.

Two things that would change the calculus, and should prompt cherry-picking the commit
onto `main` instead of waiting:

- The build gets handed to people who will open Markdown they did not write — the
  original M5 "ship to colleagues" case, or anything wider.
- Upstream goes quiet for long enough that "waiting" stops being a plan.

Note that the exfiltration half is already closed here regardless: `PreviewContentPolicy`
and `QuickLookContentPolicy` stop a document sending anything anywhere, so a read cannot
be turned into a leak by the document that caused it. What remains unfixed on this fork
is the read itself.

**F5 — manual-test `.md` files don't say what "pass" looks like.** Every fixture written
for this fork (`tests/fixtures/security/*.md`, `tests/fixtures/relative-assets/*.md`) and
every upstream demo file used the same way (`samples/*.md`) explains the threat or the
feature to a *developer*, but none of them tell a *person looking at the rendered output*
how to tell a pass from a failure. Concretely: opening `inline-html.md` and eyeballing it
gives no way to confirm the credential-harvesting section was actually blocked — the
automated `SanitizerNegativeTests` can tell, a person reading the page cannot. Same
problem the other direction: `samples/codeblocks.md`'s Mermaid block is *expected* to
fail in Quick Look (B1, upstream's bug) and *expected* to work in the app window, and
nothing on the page says so — a tester has no way to distinguish "known, acceptable" from
"newly broken."

Scope, per the user: all three locations — security fixtures, asset fixtures, and
upstream's samples.

Open design question before implementing: `samples/*.md` is upstream's file, touched on
their release cadence, so writing fork-specific pass/fail annotations directly into it is
an edit to an upstream-maintained file, not a new one — the kind of thing this fork has
otherwise avoided (see "New files are free" above). Two ways to resolve it: annotate
`samples/*.md` in place and accept the small recurring merge cost, or leave `samples/`
untouched and add a companion checklist (e.g. `docs/MANUAL-TEST-CHECKLIST.md`) mapping
each sample file and section to its expected outcome and known exceptions. The fixtures
under `tests/fixtures/` are ours either way and can be annotated directly with no such
tradeoff.

**F7 — the Application menu still said "Markdown Preview." Done.** The M2b rename only
touched `Localizable.strings`, which covers everything looked up through `L()` — the
Settings pane, dialogs, tooltips. It does not cover `MainMenu.xib`'s own menu items
("Quit", "About", "Hide", the app menu's title and submenu), which macOS resolves
straight from the nib rather than through `L()`. Three places actually needed fixing,
not one: `en.lproj/MainMenu.strings` and `zh-Hans.lproj/MainMenu.strings` (runtime
overrides for each locale) and `Base.lproj/MainMenu.xib` itself (the base text those
overrides sit on top of, and what a future locale with no override would fall back to).
All three renamed; 6 occurrences each in the base XIB and the English overrides, 12 in
the Chinese overrides (title text is compound there, e.g. `退出 MDView`).

`MainMenu.xib` also carries `customModule="Markdown_Preview"` on the AppDelegate and
document-controller objects — stale, but not a functional risk: confirmed by checking
what `ibtool` actually compiles the nib with, `--module MDView__Dev_`, sanitized from the
live `PRODUCT_NAME` and independent of whatever the XIB's own attribute says. Left
alone as out of scope for a user-visible-text fix; Interface Builder's own editor would
show the stale name if anyone opened this file there, which is the only cost.

Two menu items shared the same file, were found along the way, and — on request — removed
outright rather than left inert. **"Check for Updates…"** was already dead at runtime
(`AppDelegate` removed it from the menu at launch, a stub from M3's Sparkle removal); now
the menu item, its nib outlet, and the removal code that existed only to hide it are all
gone — the outlet had nothing left to preserve for upstream-diff-compatibility once its
only consumer was deleted. **"Send Anonymous Crash Reports"** was live and misleading —
wired to `toggleCrashReporting(_:)`, visibly shown, toggling a `CrashReporter.isEnabled`
setter that is a no-op, so the checkbox could never actually turn on; the `@IBAction`,
its `validateMenuItem` case, and the menu item are all gone too. `CrashReporter` itself
is untouched — `SettingsModel` still reads/writes `CrashReporter.isEnabled` at three call
sites, per the stub-don't-excise rule, since that state tracking outlived its own menu
item once already (M3 removed the Privacy pane's crash-reporting toggle and left this
menu item as the last surviving control). Removing both left exactly one separator
between "About MDView" and "Services" — the stock macOS application-menu shape before
either item was ever inserted.

**B1 — Mermaid in Quick Look. Resolved as an upstream bug, not ours.** Fenced `mermaid`
blocks render as raw text in a grey box in Quick Look, while syntax highlighting and the
copy button work. Confirmed on a **stock Homebrew install of upstream**, with our
extension disabled via `pluginkit -e ignore` so the baseline was honest. Upstream's
`README.md` says diagrams "render as diagrams in both the app and Quick Look previews",
and the CHANGELOG carries several Mermaid-in-Quick-Look entries, so the documentation is
wrong or the feature regressed there.

Two false leads worth recording, because both cost time:

- **The CSP was suspected first.** An A/B build with `QuickLookContentPolicy` disabled
  reproduced the failure exactly, clearing it.
- **A local reproduction was attempted in the SPM test harness and is not possible.**
  `bundledVendorScriptTag` reads from `Bundle.main`, which in an SPM test has no vendor
  resources, so the harness produced a page with no Mermaid in it at all and reported
  zero CSP violations. That looked like evidence and was not.

Also ruled out: Mermaid is present in the appex, and uses no `eval`, `Function`, workers,
blob URLs or dynamic `import()`. Quick Look renders with `vendorLoading: .inline`, so the
bundle is inlined rather than fetched over a scheme that could fail.

**Confirmed asymmetric on upstream: diagrams render in their app window and fail in their
Quick Look.** That isolates it to the Quick Look path rather than to Mermaid or the
renderer.

The leading hypothesis: Mermaid is a 3 MB bundle that renders asynchronously. The app
window has as long as it needs; a Quick Look preview may be snapshotted, or the extension
torn down, before the render completes. That fits the symptom — the figure container is
emitted, the SVG never replaces it — and is consistent with KaTeX and highlight.js
working in Quick Look, both being far smaller and finishing sooner.

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
