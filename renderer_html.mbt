///|
/// HTML renderer: converts the Markdown AST to HTML.
fn escape_html(s : String) -> String {
  let sb = StringBuilder::new()
  let len = s.length()
  let mut i = 0
  while i < len {
    let c = s[i]
    match c {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '"' => sb.write_string("&quot;")
      '\'' => sb.write_string("&#39;")
      _ => sb.write_string(String::make(1, s.unsafe_char_at(i)))
    }
    i = i + 1
  }
  sb.to_string()
}

///|
/// Render a complete Document to HTML
pub fn render_html(doc : Document) -> String {
  let sb = StringBuilder::new()
  render_blocks(doc.blocks, sb)
  sb.to_string()
}

///|
fn render_blocks(blocks : Array[Block], sb : StringBuilder) -> Unit {
  let mut i = 0
  while i < blocks.length() {
    let block = blocks[i]
    match block {
      Heading(level, inlines) => {
        let tag = level.to_string()
        sb.write_string("<h")
        sb.write_string(tag)
        sb.write_string(">")
        render_inlines(inlines, sb)
        sb.write_string("</h")
        sb.write_string(tag)
        sb.write_string(">\n")
      }
      Paragraph(inlines) => {
        sb.write_string("<p>")
        render_inlines(inlines, sb)
        sb.write_string("</p>\n")
      }
      CodeBlock(lang, code) => {
        sb.write_string("<pre><code")
        if lang.is_some() {
          sb.write_string(" class=\"language-")
          sb.write_string(escape_html(lang.unwrap()))
          sb.write_string("\"")
        }
        sb.write_string(">")
        sb.write_string(escape_html(code))
        sb.write_string("</code></pre>\n")
      }
      ThematicBreak => sb.write_string("<hr />\n")
      Blockquote(inner_blocks) => {
        sb.write_string("<blockquote>\n")
        render_blocks(inner_blocks, sb)
        sb.write_string("</blockquote>\n")
      }
      ListBlock(mode, items) =>
        match mode {
          Bullet(_) => {
            sb.write_string("<ul>\n")
            render_list_items(items, sb)
            sb.write_string("</ul>\n")
          }
          Ordered(_) => {
            sb.write_string("<ol>\n")
            render_list_items(items, sb)
            sb.write_string("</ol>\n")
          }
        }
      RawHtmlBlock(html) => {
        sb.write_string(html)
        sb.write_string("\n")
      }
    }
    i = i + 1
  }
}

///|
fn render_list_items(items : Array[ListItem], sb : StringBuilder) -> Unit {
  let mut i = 0
  while i < items.length() {
    let item = items[i]
    sb.write_string("<li>")
    render_blocks(item.blocks, sb)
    sb.write_string("</li>\n")
    i = i + 1
  }
}

///|
fn render_inlines(inlines : Array[Inline], sb : StringBuilder) -> Unit {
  let mut i = 0
  while i < inlines.length() {
    let inline = inlines[i]
    match inline {
      Text(s) => sb.write_string(escape_html(s))
      SoftBreak => sb.write_string("\n")
      HardBreak => sb.write_string("<br />\n")
      Emphasis(children) => {
        sb.write_string("<em>")
        render_inlines(children, sb)
        sb.write_string("</em>")
      }
      Strong(children) => {
        sb.write_string("<strong>")
        render_inlines(children, sb)
        sb.write_string("</strong>")
      }
      Code(code) => {
        sb.write_string("<code>")
        sb.write_string(escape_html(code))
        sb.write_string("</code>")
      }
      Link(text, url, title) => {
        sb.write_string("<a href=\"")
        sb.write_string(escape_html(url))
        sb.write_string("\"")
        if title.is_some() {
          sb.write_string(" title=\"")
          sb.write_string(escape_html(title.unwrap()))
          sb.write_string("\"")
        }
        sb.write_string(">")
        render_inlines(text, sb)
        sb.write_string("</a>")
      }
      Image(alt, url, title) => {
        sb.write_string("<img src=\"")
        sb.write_string(escape_html(url))
        sb.write_string("\" alt=\"")
        sb.write_string(escape_html(alt))
        sb.write_string("\"")
        if title.is_some() {
          sb.write_string(" title=\"")
          sb.write_string(escape_html(title.unwrap()))
          sb.write_string("\"")
        }
        sb.write_string(" />")
      }
    }
    i = i + 1
  }
}
