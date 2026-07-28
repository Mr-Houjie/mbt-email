/// mbt-markdown: A Markdown parser and HTML renderer for MoonBit.
///
/// This package provides a complete Markdown-to-HTML pipeline:
///   parse() - Parse Markdown text into an AST
///   md_to_html() - Parse and render to HTML in one step
///
/// Supported features:
///   - ATX headings (# to ######)
///   - Paragraphs with inline formatting
///   - Emphasis (*italic*, **bold**)
///   - Inline code (`code`)
///   - Fenced code blocks (```lang ... ```)
///   - Links ([text](url))
///   - Images (![alt](url))
///   - Blockquotes (> text)
///   - Unordered and ordered lists
///   - Thematic breaks (---, ***, ___)
///   - HTML escaping

/// Parse a Markdown string into its AST representation.
pub fn parse(input : String) -> Document {
  parse_document(input)
}

/// Parse a Markdown string and render it to HTML in one step.
///
/// Example:
/// ```
/// let html = md_to_html("# Hello\n\nWorld")
/// // <h1>Hello</h1>
/// // <p>World</p>
/// ```
pub fn md_to_html(input : String) -> String {
  let doc = parse_document(input)
  render_html(doc)
}
