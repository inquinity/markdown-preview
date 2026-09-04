import Foundation
import XCTest
@testable import MarkdownHelpers

/// What the `md-asset:` scheme will and will not resolve.
///
/// The rendered page's `<base href>` mirrors the document folder, so WebKit
/// resolves relative references *before* they reach the scheme handler. An
/// `md-asset:` URL's path is therefore an absolute filesystem path, and
/// `MarkdownAssetResolution.fileURL(for:)` decides what gets read off disk.
///
/// This file used to assert a **known gap**: `fileURL(for:)` took no base
/// folder, so `md-asset:///etc/passwd` resolved and the handler served it.
/// Those two tests were written to fail the day the behaviour improved, and
/// they did. The fix — GHSA-vgmc-h5g6-xh2q, submitted upstream as PR #337 —
/// is carried on this fork ahead of that merge, so the gap tests are now
/// inverted into the containment assertions below.
///
/// Fixture: `tests/fixtures/security/path-traversal.md`.
final class AssetContainmentTests: XCTestCase {

    /// The folder a document lives in. Resolution is confined to it.
    private let documentFolder = URL(fileURLWithPath: "/tmp/mdp-doc", isDirectory: true)

    private func resolved(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString) else {
            XCTFail("could not parse \(urlString)")
            return nil
        }
        return MarkdownAssetResolution.fileURL(for: url, containedIn: documentFolder)
    }

    // MARK: - Real guarantees

    /// `//host/pic.png` in a document is protocol-relative and resolves to an
    /// `md-asset:` URL carrying a host. Rejecting those stops it aliasing a
    /// local file.
    func testURLsCarryingAHostAreRejected() {
        XCTAssertNil(resolved("md-asset://evil.invalid/etc/passwd"))
        XCTAssertNil(resolved("md-asset://localhost/etc/passwd"))
    }

    func testOtherSchemesAreRejected() {
        XCTAssertNil(resolved("file:///etc/passwd"))
        XCTAssertNil(resolved("https://example.invalid/x.png"))
        XCTAssertNil(resolved("javascript:alert(1)"))
    }

    func testTheBareRootIsRejected() {
        XCTAssertNil(resolved("md-asset:///"))
    }

    func testTraversalSegmentsAreStandardizedAwayRatherThanPassedThrough() {
        // Not a containment check — just proof that what reaches the filesystem
        // is a normalized path, so the assertions below describe real reads.
        // The path stays inside the document folder on purpose: traversal that
        // leaves it is now rejected outright, which the containment tests cover.
        let url = resolved("md-asset:///tmp/mdp-doc/notes/../notes/./diagram.png")
        XCTAssertEqual(url?.path, "/tmp/mdp-doc/notes/diagram.png")
    }

    // MARK: - Containment (was the known gap -- M4 / GHSA-vgmc-h5g6-xh2q)

    /// `![](../../../../etc/passwd)` in a document resolves, against the
    /// page's base href, to this URL. It used to be served; it must not be.
    ///
    /// **If this test fails, the containment fix has been lost** -- most
    /// likely by a merge from upstream landing before their version of the
    /// fix does. A document can then read any file the app can.
    func testTraversalOutsideTheDocumentFolderIsRejected() {
        XCTAssertNil(
            resolved("md-asset:///etc/passwd"),
            "md-asset: resolved a path outside the document folder. Containment is gone."
        )
    }

    /// The same gap by a shorter route: a root-absolute reference needs no
    /// traversal at all.
    func testRootAbsolutePathsOutsideTheFolderAreRejected() {
        XCTAssertNil(
            resolved("md-asset:///Users/someone/.ssh/id_rsa"),
            "md-asset: resolved an unrelated absolute path. Containment is gone."
        )
    }

    /// The positive half: a file genuinely inside the document folder still
    /// resolves, so containment has not simply broken image loading.
    func testAssetInsideTheDocumentFolderResolves() {
        XCTAssertEqual(
            resolved("md-asset:///tmp/mdp-doc/images/pic.png")?.path,
            "/tmp/mdp-doc/images/pic.png"
        )
    }

    /// A sibling directory sharing a name prefix must not pass the check --
    /// `/tmp/mdp-doc-evil` starts with `/tmp/mdp-doc` as a *string* but is not
    /// inside it. Prefix comparison without the trailing separator would admit
    /// it.
    func testSiblingFolderSharingANamePrefixIsRejected() {
        XCTAssertNil(
            resolved("md-asset:///tmp/mdp-doc-evil/secret.png"),
            """
            A sibling folder whose name merely starts with the document \
            folder's name was admitted. The containment check is comparing \
            strings without the trailing path separator.
            """
        )
    }
}
