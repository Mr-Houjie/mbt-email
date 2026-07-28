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

/// Parse a Markdown string and extract plain text (no formatting).
///
/// Strips all markup and returns readable plain text, useful for:
///   - Search indexing
///   - LLM context preparation
///   - Plain text previews
pub fn md_to_text(input : String) -> String {
  let doc = parse_document(input)
  render_text(doc)
}

fn render_text(doc : Document) -> String {
  let sb = StringBuilder::new()
  render_blocks_text(doc.blocks, sb)
  sb.to_string()
}

fn render_blocks_text(blocks : Array[Block], sb : StringBuilder) -> Unit {
  let mut i = 0
  while i < blocks.length() {
    let block = blocks[i]
    match block {
      Heading(_, inlines) => {
        render_inlines_text(inlines, sb)
        sb.write_string("\n\n")
      }
      Paragraph(inlines) => {
        render_inlines_text(inlines, sb)
        sb.write_string("\n\n")
      }
      CodeBlock(_, code) => {
        sb.write_string(code)
        sb.write_string("\n\n")
      }
      ThematicBreak => sb.write_string("\n---\n\n")
      Blockquote(inner_blocks) => {
        render_blocks_text(inner_blocks, sb)
      }
      ListBlock(_, items) => {
        let mut j = 0
        while j < items.length() {
          let item = items[j]
          sb.write_string("- ")
          render_blocks_text(item.blocks, sb)
          j = j + 1
        }
        sb.write_string("\n")
      }
      RawHtmlBlock(_) => ()
    }
    i = i + 1
  }
}

fn render_inlines_text(inlines : Array[Inline], sb : StringBuilder) -> Unit {
  let mut i = 0
  while i < inlines.length() {
    let inline = inlines[i]
    match inline {
      Text(s) => sb.write_string(s)
      SoftBreak => sb.write_string("\n")
      HardBreak => sb.write_string("\n")
      Emphasis(children) => render_inlines_text(children, sb)
      Strong(children) => render_inlines_text(children, sb)
      Code(code) => sb.write_string(code)
      Link(text, _, _) => render_inlines_text(text, sb)
      Image(alt, _, _) => sb.write_string(alt)
    }
    i = i + 1
  }
}
