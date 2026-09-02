# Asset references that reach outside the document folder

The rendered page's `<base href>` is an `md-asset:` URL mirroring the document's
folder, so WebKit resolves every reference below *before* it reaches
`MarkdownAssetSchemeHandler`. An `md-asset:` URL's path is therefore the
absolute path of a file on disk.

`MarkdownAssetResolution.fileURL(for:)` performs no containment check — it
returns whatever absolute path it is handed. Combined with the app's
`temporary-exception.files.absolute-path.read-only` entitlement of `/`, that
means document content can cause any file the user can read to be read off disk
and handed to WebKit.

This is upstream behaviour, and deliberate on their part: parent-folder image
references are a supported feature. It is reported upstream as
GHSA-vgmc-h5g6-xh2q and tracked here as M4.

**The tests over this file assert the CURRENT, permissive behaviour.** They are
written to fail the moment it changes, so that when upstream's fix or our own
containment lands, the change is noticed and the assertions are inverted rather
than silently left stale. See `AssetContainmentTests`.

## Traversal out of the document folder

![escaping upwards](../../../../etc/passwd)

![sibling folder](../other-project/secrets.txt)

## Root-absolute paths

Resolved against the `md-asset:` origin, not the document folder.

![absolute](/etc/hosts)

![user data](/Users/someone/.ssh/id_rsa)

## Protocol-relative, which must stay rejected

`fileURL(for:)` rejects URLs carrying a host, so this must not alias a local
file. That check is real and worth keeping a test on.

![protocol relative](//evil.invalid/pic.png)
