///|
/// mbt-markdown - Full feature demonstration.
fn main {
  let input = "# Hello, mbt-markdown!\n\n" +
    "This is a **Markdown** parser written in **MoonBit**.\n\n" +
    "## Features\n\n" +
    "- **Headings** (*h1* to *h6*)\n" +
    "- *Emphasis* and **strong** text\n" +
    "- `Inline code`\n" +
    "- [Links](https://moonbitlang.com)\n" +
    "- Code blocks\n\n" +
    "### Inline Formatting\n\n" +
    "Here is **bold**, *italic*, and `code`.\n\n" +
    "### Code Example\n\n" +
    "```rust\n" +
    "fn hello() {\n" +
    "    println!(\"Hello, world!\");\n" +
    "}\n" +
    "```\n\n" +
    "### Blockquote\n\n" +
    "> This is a blockquote.\n" +
    "> It spans multiple lines.\n\n" +
    "### Thematic Break\n\n" +
    "---\n\n" +
    "Created with ❤️\n"
  let html = @lib.md_to_html(input)
  println(html)
}
