# Markdown Preview — agent guide

> ## ⚠️ FORK STATUS — read before acting on anything below
>
> This is **[inquinity/markdown-preview](https://github.com/inquinity/markdown-preview)**,
> a fork of pluk-inc/markdown-preview. Read
> **[docs/FORK-NOTES.md](docs/FORK-NOTES.md)** first — it is the source of truth for how
> this repository differs from the document below.
>
> - **Releases go through `scripts/build-release.sh`.** Upstream's `release.sh` and
>   `rollback-release.sh` drove the Amore CLI against their account and have been removed.
> - The **Project facts** table below is upstream's and is now partly wrong: this fork
>   builds as `com.altmansoftwaredesign.markdown-preview` under team `45GJWJVQN2`.
>   See the Signing configuration section.
> - The fork carries **deliberately dead code** — an orphaned CLI installer and stubbed
>   telemetry reporters. This is load-bearing for cheap upstream merges. Do not remove it.
> - Sync with `git merge upstream/main`. **Never rebase `main`** — it is published.
>
> Everything after this block is upstream's documentation, preserved as-is.

A macOS app for previewing Markdown files. AppKit, sandboxed, ships with a Quick Look extension. Updates via Sparkle; this fork is distributed by hand.

## Project facts

| Thing | Value |
|---|---|
| Bundle id | `doc.md-preview` |
| Product name | `Markdown Preview` |
| Scheme | `md-preview` |
| Quick Look target | `quick-look` (embedded extension) |
| Min macOS | 15.0 |
| Sandboxed | yes — uses Sparkle XPC services for updates |
| Auto-updater | Sparkle 2.x (Swift package) |
| Distribution      | By hand — see `docs/INTERNAL-INSTALL.md`                    |

Version is managed centrally in `Version.xcconfig` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`). Both the app and the quick-look extension inherit from it.

## Release pipeline

This fork builds and hands out the DMG directly. There is no hosted appcast, no
Sparkle feed and no GitHub release — see `docs/INTERNAL-INSTALL.md` for how
recipients install it.

Before releasing, **add a `CHANGELOG.md` entry** for the version being shipped;
the script refuses to build without one. **Always invoke the
`changelog-maintenance` skill** via the Skill tool when writing that entry —
do not draft freeform.

```bash
./scripts/build-release.sh                    # build the version in Version.xcconfig
./scripts/build-release.sh --version 0.0.53   # bump the marketing version first
./scripts/build-release.sh --version 0.0.53 --build 57
./scripts/build-release.sh --dry-run          # print every step, build nothing
./scripts/build-release.sh --skip-notarize    # local smoke test; will NOT open elsewhere
```

The script archives, exports a Developer ID build, notarizes and staples the
app, packages the DMG, then signs, notarizes and staples the DMG in its own
right. Two notarization submissions: Gatekeeper assesses what the reader
downloaded, not only the app inside it, and `hdiutil` leaves the image unsigned.
It finishes with an `spctl` assessment and refuses to report success if that
fails.

Version numbers live once, in `Version.xcconfig`. Release notes live in
`CHANGELOG.md`.

## Rolling back a release

Nothing is published, so there is nothing to unpublish. Withdraw a bad build by
deleting the DMG from wherever it was shared and handing out the previous one.
Tell anyone who already installed it — without Sparkle, no update reaches them
on its own.

## Signing configuration

| Thing | Value |
|---|---|
| Team ID | `45GJWJVQN2` (Altman Software Design, LLC) |
| Signing identity | `Developer ID Application: Altman Software Design, LLC (45GJWJVQN2)` |
| Notary keychain profile | `altman-notary` |
| Certificate expires | 2031-05-27 |

The notary profile is not per-project — it stores an Apple ID, team ID and
app-specific password, so one profile covers everything shipped under this team.
Recreate it with:

```bash
xcrun notarytool store-credentials "altman-notary" --team-id 45GJWJVQN2
```

If `codesign` fails with `errSecInternalComponent`, the private key's ACL is
refusing non-interactive use. Fix it once with:

```bash
security set-key-partition-list -S apple-tool:,apple:,codesign: -s ~/Library/Keychains/login.keychain-db
```

## Common Xcode tasks

```bash
xcodebuild -project md-preview.xcodeproj -scheme md-preview -configuration Debug build
xcodebuild -resolvePackageDependencies -project md-preview.xcodeproj
```

Sparkle helper tools (sign_update / generate_keys / generate_appcast) live at:
`~/Library/Developer/Xcode/DerivedData/md-preview-*/SourcePackages/artifacts/sparkle/Sparkle/bin/`
