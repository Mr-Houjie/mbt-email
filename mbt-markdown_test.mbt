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

///| Image
test "image" {
  let html = @houjie/mbt-markdown.md_to_html("![alt](https://example.com/img.png)\n")
  assert_eq(html, "<p><img src=\"https://example.com/img.png\" alt=\"alt\" /></p>\n")
}

///| Fenced code block
test "code_block" {
  let html = @houjie/mbt-markdown.md_to_html("```\nfn main() {\n  println!()\n}\n```\n")
  assert_eq(html, "<pre><code>fn main() {\n  println!()\n}</code></pre>\n")
}

///| Fenced code block with language
test "code_block_with_lang" {
  let html = @houjie/mbt-markdown.md_to_html("```rust\nfn main() {}\n```\n")
  assert_eq(html, "<pre><code class=\"language-rust\">fn main() {}</code></pre>\n")
}

///| Ordered list
test "ordered_list" {
  let html = @houjie/mbt-markdown.md_to_html("1. First\n2. Second\n")
  assert_eq(html, "<ol>\n<li><p>First</p>\n</li>\n<li><p>Second</p>\n</li>\n</ol>\n")
}

///| Unordered list
test "unordered_list" {
  let html = @houjie/mbt-markdown.md_to_html("- one\n- two\n")
  assert_eq(html, "<ul>\n<li><p>one</p>\n</li>\n<li><p>two</p>\n</li>\n</ul>\n")
}

///| HTML escaping
test "html_escaping" {
  let html = @houjie/mbt-markdown.md_to_html("<script>\n")
  assert_eq(html, "<p>&lt;script&gt;</p>\n")
}

///| Nested emphasis (strong containing emphasis)
test "nested_emphasis" {
  let html = @houjie/mbt-markdown.md_to_html("**_bold italic_**\n")
  assert_eq(html, "<p><strong><em>bold italic</em></strong></p>\n")
}

///| Multiple headings
test "heading_h3" {
  let html = @houjie/mbt-markdown.md_to_html("### H3\n")
  assert_eq(html, "<h3>H3</h3>\n")
}

///| Hard line break (two trailing spaces)
test "hard_break" {
  let html = @houjie/mbt-markdown.md_to_html("line 1  \nline 2\n")
  assert_eq(html, "<p>line 1<br />\nline 2</p>\n")
}
