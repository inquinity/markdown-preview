# Remote references that disclose the reader

Every reference below is a tracking pixel. Rendering this document tells
`example.invalid` that the file was opened, from which IP, and at what time —
and the query strings show how an author can identify *which* document and
recipient without any cooperation from the reader.

Both surfaces block these, and neither does it with the sandbox — both targets
must keep `com.apple.security.network.client` or WKWebView renders nothing at
all, so the block lives in the page:

- **Quick Look** — `QuickLookContentPolicy`. Guarded by
  `QuickLookContentPolicyTests`.
- **The app window and editor** — `PreviewContentPolicy`. Guarded by
  `PreviewContentPolicyTests`.

The two policies are deliberately separate and must not be merged. Quick Look
inlines its vendor bundles and carries images as `data:`/`cid:`; the app page
fetches scripts and images over the `md-asset:` scheme. A single shared policy
would have to permit the union of both, which is weaker than either.

DOMPurify still keeps these `<img>` elements in the DOM — `ALLOWED_URI_REGEXP`
permits `http`/`https` — so they appear as broken images rather than vanishing.
The load is what is refused. Tightening that regexp is the belt to this braces
and is on the upstream contribution track.

## Image beacons

![](https://example.invalid/pixel.png?doc=quarterly-results&reader=alice)

![](http://example.invalid/plain-http.png)

## Referenced via inline HTML

<img src="https://example.invalid/inline.png?via=raw-html">

## Remote stylesheet and font

Both are denied by `default-src 'none'` in the Quick Look policy.

<link rel="stylesheet" href="https://example.invalid/theme.css">
