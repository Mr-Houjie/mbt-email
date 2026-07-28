///|
/// AST node types for Markdown documents.
/// Represents the structural elements of a Markdown document.

///|
/// Inline-level elements (content inside paragraphs, headings, etc.)
pub enum Inline {
  /// Plain text content
  Text(String)
  /// Soft line break (newline in source, rendered as space)
  SoftBreak
  /// Hard line break (two trailing spaces or backslash)
  HardBreak
  /// Italic / emphasis: *text* or _text_
  Emphasis(Array[Inline])
  /// Bold / strong emphasis: **text** or __text__
  Strong(Array[Inline])
  /// Inline code: `code`
  Code(String)
  /// Inline link: [text](url) or [text](url "title")
  Link(Array[Inline], String, String?)
  /// Inline image: ![alt](url) or ![alt](url "title")
  Image(String, String, String?)
}

///|
/// Block-level elements (top-level structure of a Markdown document)
pub enum Block {
  /// ATX heading: # to ######
  Heading(Int, Array[Inline])
  /// Paragraph of inline content
  Paragraph(Array[Inline])
  /// Fenced code block: ```lang ... ```
  CodeBlock(String?, String)
  /// Thematic break: --- or *** or ___
  ThematicBreak
  /// Blockquote: > text
  Blockquote(Array[Block])
  /// Unordered / ordered list
  ListBlock(ListMode, Array[ListItem])
  /// Raw HTML block (pass-through)
  RawHtmlBlock(String)
}

///|
/// Mode of a list: bullet or ordered
pub enum ListMode {
  Bullet(String)
  Ordered(Int)
}

///|
/// A single list item
pub struct ListItem {
  blocks : Array[Block]
  checked : Bool?
}

///|
/// A complete Markdown document
pub struct Document {
  blocks : Array[Block]
}
