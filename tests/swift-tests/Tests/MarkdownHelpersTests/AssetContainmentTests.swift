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
/// Some of these assert real guarantees. Two assert a **known gap** —
/// deliberately, so that the day the behaviour improves, the test fails and
/// someone inverts it rather than leaving a stale comment behind. The gap is
/// reported upstream as GHSA-vgmc-h5g6-xh2q and tracked here as M4.
///
/// Fixture: `tests/fixtures/security/path-traversal.md`.
final class AssetContainmentTests: XCTestCase {

    private func resolved(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString) else {
            XCTFail("could not parse \(urlString)")
            return nil
        }
        return MarkdownAssetResolution.fileURL(for: url)
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
        let url = resolved("md-asset:///Users/me/notes/../notes/./diagram.png")
        XCTAssertEqual(url?.path, "/Users/me/notes/diagram.png")
    }

    // MARK: - Known gap (M4 / GHSA-vgmc-h5g6-xh2q)

    /// KNOWN GAP. `![](../../../../etc/passwd)` in a document resolves, against
    /// the page's base href, to this URL — and the handler serves it.
    ///
    /// If this test starts failing, containment has been added. That is the
    /// desired outcome: invert the assertion, and close M4 in
    /// docs/FORK-NOTES.md.
    func testTraversalOutsideTheDocumentFolderStillResolves_knownGap() {
        XCTAssertEqual(
            resolved("md-asset:///etc/passwd")?.path, "/etc/passwd",
            """
            md-asset: no longer resolves paths outside the document folder. \
            If that was intentional, invert this test and close M4.
            """
        )
    }

    /// KNOWN GAP, the same one by a shorter route: a root-absolute reference
    /// needs no traversal at all.
    func testRootAbsolutePathsStillResolve_knownGap() {
        XCTAssertEqual(
            resolved("md-asset:///Users/someone/.ssh/id_rsa")?.path,
            "/Users/someone/.ssh/id_rsa"
        )
    }

    /// The containment check M4 would add, expressed as the test it will need.
    /// Skipped until then so the intended behaviour is written down in
    /// executable form rather than only in prose.
    func testResolutionIsConfinedToTheDocumentFolder() throws {
        try XCTSkipIf(
            true,
            """
            Pending M4 (or upstream's fix for GHSA-vgmc-h5g6-xh2q). When \
            fileURL(for:) takes a base folder and rejects anything outside it, \
            remove this skip and delete the two _knownGap tests above.
            """
        )
    }
}
