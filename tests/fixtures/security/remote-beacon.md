# Remote references that disclose the reader

Every reference below is a tracking pixel. Rendering this document tells
`example.invalid` that the file was opened, from which IP, and at what time —
and the query strings show how an author can identify *which* document and
recipient without any cooperation from the reader.

Two different mitigations apply, and they are not the same strength:

- **Quick Look** — blocked. The extension holds
  `com.apple.security.network.client` (it renders blank without it), so the
  sandbox cannot help; `QuickLookContentPolicy` denies remote origins in the
  page instead. `QuickLookContentPolicyTests` guards that.
- **The main app window** — *not* blocked. That page has no CSP, and
  DOMPurify's `ALLOWED_URI_REGEXP` permits `http`/`https`. The app itself makes
  no connections, but content it renders still can. Reported upstream and
  tracked here as F2.

Do not "fix" the app-window gap by pointing `QuickLookContentPolicy` at that
page: it serves scripts and images over the `md-asset:` scheme and the Quick
Look policy would break it.

## Image beacons

![](https://example.invalid/pixel.png?doc=quarterly-results&reader=alice)

![](http://example.invalid/plain-http.png)

## Referenced via inline HTML

<img src="https://example.invalid/inline.png?via=raw-html">

## Remote stylesheet and font

Both are denied by `default-src 'none'` in the Quick Look policy.

<link rel="stylesheet" href="https://example.invalid/theme.css">
