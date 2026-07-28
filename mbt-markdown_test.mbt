// Blackbox tests for mbt-markdown.
// Run with: moon test

///| Basic heading parsing
test "heading" {
  let html = @houjie/mbt-markdown.md_to_html("# Hello\n")
  assert_eq(html, "<h1>Hello</h1>\n")
}

///| Strong emphasis
test "strong" {
  let html = @houjie/mbt-markdown.md_to_html("**bold**\n")
  assert_eq(html, "<p><strong>bold</strong></p>\n")
}

///| Emphasis
test "emphasis" {
  let html = @houjie/mbt-markdown.md_to_html("*italic*\n")
  assert_eq(html, "<p><em>italic</em></p>\n")
}

///| Inline code
test "inline_code" {
  let html = @houjie/mbt-markdown.md_to_html("`code`\n")
  assert_eq(html, "<p><code>code</code></p>\n")
}

///| Link
test "link" {
  let html = @houjie/mbt-markdown.md_to_html("[text](https://example.com)\n")
  assert_eq(html, "<p><a href=\"https://example.com\">text</a></p>\n")
}

///| Paragraph
test "paragraph" {
  let html = @houjie/mbt-markdown.md_to_html("Hello world\n")
  assert_eq(html, "<p>Hello world</p>\n")
}

///| Thematic break
test "thematic_break" {
  let html = @houjie/mbt-markdown.md_to_html("---\n")
  assert_eq(html, "<hr />\n")
}

///| Blockquote
test "blockquote" {
  let html = @houjie/mbt-markdown.md_to_html("> Quote\n")
  assert_eq(html, "<blockquote>\n<p>Quote</p>\n</blockquote>\n")
}
