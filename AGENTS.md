# Markdown Preview — agent guide

> ## ⚠️ FORK STATUS — read before acting on anything below
>
> This is **[inquinity/markdown-preview](https://github.com/inquinity/markdown-preview)**,
> a fork of pluk-inc/markdown-preview. Read
> **[docs/FORK-NOTES.md](docs/FORK-NOTES.md)** first — it is the source of truth for how
> this repository differs from the document below.
>
> - **Releases go through `scripts/build.sh --release`.** It builds, signs, notarizes
>   and packages a DMG into `dist/`, with no `CHANGELOG.md` requirement. It reuses
>   `Version.xcconfig` and composes with `--update` to bump the version first.
>   `scripts/build-release.sh` also works and produces the same kind of artifact via a
>   different (archive/export) path, gated on a `CHANGELOG.md` entry, but it is not the
>   one actually in use — don't default to it. Upstream's `release.sh` and
>   `rollback-release.sh` drove the Amore CLI against their account and have been removed.
> - The **Project facts** table below is upstream's and is now partly wrong: this fork
>   builds as `com.altmansoftwaredesign.markdown-preview` under team `45GJWJVQN2`.
>   See the Signing configuration section.
> - The fork carries **deliberately dead code** — an orphaned CLI installer and stubbed
>   telemetry reporters. This is load-bearing for cheap upstream merges. Do not remove it.
> - Sync with `git merge upstream/main`. **Never rebase `main`** — it is published.
>
> Everything after this block is upstream's documentation, preserved as-is.

A macOS app for previewing Markdown files. AppKit, sandboxed, ships with a Quick Look extension. This fork has no auto-updater and is distributed by hand.

## Project facts

| Thing             | Value                                                       |
| ----------------- | ----------------------------------------------------------- |
| Bundle id         | `doc.md-preview`                                            |
| Product name      | `MDView` (renamed in this fork)                             |
| Scheme            | `md-preview`                                                |
| Quick Look target | `quick-look` (embedded extension)                           |
| Min macOS         | 15.0                                                        |
| Sandboxed         | yes                                                         |
| Auto-updater      | none — Sparkle removed in this fork                         |
| Distribution      | By hand — see `docs/INTERNAL-INSTALL.md`                    |

Version is managed centrally in `Version.xcconfig` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`). Both the app and the quick-look extension inherit from it.

## Release pipeline

This fork builds and hands out the DMG directly. There is no hosted appcast, no
Sparkle feed and no GitHub release — see `docs/INTERNAL-INSTALL.md` for how
recipients install it.

**The release script in actual use is `scripts/build.sh --release`**, not
`scripts/build-release.sh`. No `CHANGELOG.md` entry is required — that gate exists
only on the other script, which is not part of this workflow. Don't reach for it, and
don't hold a release back to write a changelog entry that nothing here checks for.

```bash
./scripts/build.sh                            # local .app only, in ./build
./scripts/build.sh --release                  # + a signed, notarized DMG in ./dist
./scripts/build.sh --update revision --release   # bump the version first, then release
./scripts/build.sh --update minor --release
```

`--release` fails immediately, before compiling, if the Developer ID identity or the
notary profile aren't in the keychain — it never falls back to an ad-hoc signature the
way a plain build does, since a "release" DMG nobody else's Mac can open isn't worth
producing quietly. It reuses the compile it already did for the plain build rather than
re-archiving, then packages, signs, notarizes and staples the DMG, finishing with an
`spctl` Gatekeeper check. Two notarization submissions happen along the way — the app,
then the disk image — because Gatekeeper assesses what the reader downloaded, not only
the app inside it, and `hdiutil` leaves the image itself unsigned.

`scripts/build-release.sh` still exists and still works — archive/export instead of a
plain build, gated on a `## [X.Y.Z]` entry in `CHANGELOG.md`. If that gate is ever
wanted again, invoke the `changelog-maintenance` skill for the entry rather than
drafting one freeform; until then, treat the script as unused.

Version numbers live once, in `Version.xcconfig`. `scripts/build.sh --update
{major,minor,revision}` bumps them and the build number together.

Two more local-only helpers, both operating on `./build/MDView.app` (a plain build's
output, not `--release`'s DMG): `scripts/bundle.sh` zips it for sneaker-net transfer,
`scripts/install.sh` copies it into `/Applications` and launches it once — required for
Quick Look to register, see `docs/INTERNAL-INSTALL.md`.

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

