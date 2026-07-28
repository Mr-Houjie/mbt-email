/// Inline lexer/parser: breaks a string into Inline AST nodes.
struct InlineCtx {
  s : String
  pos : Int
  len : Int
}

fn InlineCtx::new(s : String) -> InlineCtx {
  { s, pos: 0, len: s.length() }
}

fn peek(ctx : InlineCtx) -> Char? {
  ctx.s.get_char(ctx.pos)
}

fn advance(ctx : InlineCtx) -> InlineCtx {
  { s: ctx.s, pos: ctx.pos + 1, len: ctx.len }
}

fn peek_next(ctx : InlineCtx) -> Char? {
  ctx.s.get_char(ctx.pos + 1)
}

/// Parse inline content from a string
pub fn parse_inlines(s : String) -> Array[Inline] {
  let ctx = InlineCtx::new(s)
  parse_inlines_until(ctx, None).0
}

fn parse_inlines_until(
  ctx : InlineCtx,
  until_delim : Char?,
) -> (Array[Inline], InlineCtx) {
  let nodes : Array[Inline] = []
  let mut cur = ctx
  while true {
    let ch = peek(cur)
    if ch.is_none() {
      break
    }
    let c = ch.unwrap()
    if until_delim.is_some() && until_delim.unwrap() == c {
      break
    }

    match c {
      '\\' => {
        let nxt = peek_next(cur)
        if nxt.is_some() {
          nodes.push(Text(String::make(1, nxt.unwrap())))
          cur = advance(advance(cur))
        } else {
          nodes.push(Text("\\"))
          cur = advance(cur)
        }
      }
      '`' => {
        let (code, new_ctx) = parse_code_span(cur)
        nodes.push(Code(code))
        cur = new_ctx
      }
      '*' | '_' => {
        let (result, new_ctx) = parse_emphasis(cur)
        nodes.push(result)
        cur = new_ctx
      }
      '!' => {
        let nxt = peek_next(cur)
        if nxt.is_some() && nxt.unwrap() == '[' {
          let (img, new_ctx) = parse_image(cur)
          nodes.push(img)
          cur = new_ctx
        } else {
          nodes.push(Text("!"))
          cur = advance(cur)
        }
      }
      '[' => {
        let (link, new_ctx) = parse_link(cur)
        nodes.push(link)
        cur = new_ctx
      }
      '\n' => {
        let is_hard = if nodes.length() > 0 {
          match nodes[nodes.length() - 1] {
            Text(s) => {
              let slen = s.length()
              slen >= 2 && s[slen - 1] == ' ' && s[slen - 2] == ' '
            }
            _ => false
          }
        } else {
          false
        }
        if is_hard {
          match nodes[nodes.length() - 1] {
            Text(s) => {
              let mut end = s.length()
              while end > 0 && s[end - 1] == ' ' {
                end = end - 1
              }
              nodes[nodes.length() - 1] = Text(
                s.substring(start=0, end=end),
              )
            }
            _ => ()
          }
          nodes.push(HardBreak)
        } else {
          nodes.push(SoftBreak)
        }
        cur = advance(cur)
      }
      _ => {
        let sb = StringBuilder::new()
        while true {
          let ch2 = peek(cur)
          if ch2.is_none() {
            break
          }
          let c2 = ch2.unwrap()
          if until_delim.is_some() && until_delim.unwrap() == c2 {
            break
          }
          if c2 == '*' ||
            c2 == '_' ||
            c2 == '`' ||
            c2 == '[' ||
            c2 == '!' ||
            c2 == '\\' ||
            c2 == '\n' {
            break
          }
          sb.write_string(String::make(1, c2))
          cur = advance(cur)
        }
        let text = sb.to_string()
        if text.length() > 0 {
          nodes.push(Text(text))
        }
      }
    }
  }
  (nodes, cur)
}

fn parse_code_span(ctx : InlineCtx) -> (String, InlineCtx) {
  let mut backtick_count = 0
  let mut cur = ctx
  while true {
    if peek(cur).is_none() || peek(cur).unwrap() != '`' {
      break
    }
    backtick_count = backtick_count + 1
    cur = advance(cur)
  }

  let sb = StringBuilder::new()
  while true {
    let ch = peek(cur)
    if ch.is_none() {
      break
    }
    if ch.unwrap() == '`' {
      let mut close_count = 0
      let mut tmp = cur
      while true {
        if peek(tmp).is_some() && peek(tmp).unwrap() == '`' {
          close_count = close_count + 1
          tmp = advance(tmp)
        } else {
          break
        }
      }
      if close_count == backtick_count {
        cur = tmp
        break
      } else {
        sb.write_string("`")
        cur = advance(cur)
      }
    } else {
      sb.write_string(String::make(1, ch.unwrap()))
      cur = advance(cur)
    }
  }
  (sb.to_string(), cur)
}

fn parse_emphasis(ctx : InlineCtx) -> (Inline, InlineCtx) {
  let ch = peek(ctx)
  if ch.is_none() {
    return (Text(""), ctx)
  }
  let delim = ch.unwrap()
  let mut cur = advance(ctx)
  let mut strong = false

  if peek(cur).is_some() && peek(cur).unwrap() == delim {
    strong = true
    cur = advance(cur)
  }

  let (content, remaining) = parse_inlines_until(cur, Some(delim))

  if peek(remaining).is_some() && peek(remaining).unwrap() == delim {
    let after = advance(remaining)
    if strong {
      if peek(after).is_some() && peek(after).unwrap() == delim {
        (Strong(content), advance(after))
      } else {
        (Strong(content), after)
      }
    } else {
      (Emphasis(content), after)
    }
  } else {
    let sb = StringBuilder::new()
    sb.write_string(String::make(1, delim))
    if strong {
      sb.write_string(String::make(1, delim))
    }
    sb.write_string(inlines_to_raw_text(content))
    (Text(sb.to_string()), remaining)
  }
}

fn parse_link(ctx : InlineCtx) -> (Inline, InlineCtx) {
  let mut cur = advance(ctx)
  let (text, after_text) = parse_inlines_until(cur, Some(']'))

  if peek(after_text).is_none() || peek(after_text).unwrap() != ']' {
    return (Text("[" + inlines_to_raw_text(text)), after_text)
  }
  cur = advance(after_text)

  if peek(cur).is_none() || peek(cur).unwrap() != '(' {
    return (Text("[" + inlines_to_raw_text(text) + "]"), cur)
  }
  cur = advance(cur)

  let url_b = StringBuilder::new()
  while true {
    if peek(cur).is_none() || peek(cur).unwrap() == ')' {
      break
    }
    let c = peek(cur).unwrap()
    if c == ' ' {
      let after_space = advance(cur)
      if peek(after_space).is_some() &&
        (
          peek(after_space).unwrap() == '"' ||
          peek(after_space).unwrap() == '\''
        ) {
        let title_char = peek(after_space).unwrap()
        let mut title_cur = advance(after_space)
        let title_b = StringBuilder::new()
        while true {
          if peek(title_cur).is_none() {
            break
          }
          if peek(title_cur).unwrap() == title_char {
            title_cur = advance(title_cur)
            if peek(title_cur).is_some() && peek(title_cur).unwrap() == ')' {
              let title = title_b.to_string()
              let title_opt = if title.length() > 0 {
                Some(title)
              } else {
                None
              }
              let url = url_b.to_string()
              return (Link(text, url, title_opt), advance(title_cur))
            }
            break
          }
          title_b.write_string(
            String::make(1, peek(title_cur).unwrap()),
          )
          title_cur = advance(title_cur)
        }
        url_b.write_string(" ")
      } else {
        url_b.write_string(" ")
        cur = after_space
      }
    } else {
      url_b.write_string(String::make(1, c))
      cur = advance(cur)
    }
  }

  if peek(cur).is_some() && peek(cur).unwrap() == ')' {
    (Link(text, url_b.to_string(), None), advance(cur))
  } else {
    (Text("[" + inlines_to_raw_text(text) + "](" + url_b.to_string()), cur)
  }
}

fn parse_image(ctx : InlineCtx) -> (Inline, InlineCtx) {
  let mut cur = advance(advance(ctx))
  let (alt_text, after_alt) = parse_inlines_until(cur, Some(']'))

  if peek(after_alt).is_none() || peek(after_alt).unwrap() != ']' {
    return (Text("![" + inlines_to_raw_text(alt_text)), after_alt)
  }
  cur = advance(after_alt)

  if peek(cur).is_none() || peek(cur).unwrap() != '(' {
    return (Text("![" + inlines_to_raw_text(alt_text) + "]"), cur)
  }
  cur = advance(cur)

  let url_b = StringBuilder::new()
  while true {
    if peek(cur).is_none() || peek(cur).unwrap() == ')' {
      break
    }
    let c = peek(cur).unwrap()
    if c == ' ' {
      let after_space = advance(cur)
      if peek(after_space).is_some() &&
        (
          peek(after_space).unwrap() == '"' ||
          peek(after_space).unwrap() == '\''
        ) {
        let title_char = peek(after_space).unwrap()
        let mut title_cur = advance(after_space)
        let title_b = StringBuilder::new()
        while true {
          if peek(title_cur).is_none() {
            break
          }
          if peek(title_cur).unwrap() == title_char {
            title_cur = advance(title_cur)
            if peek(title_cur).is_some() && peek(title_cur).unwrap() == ')' {
              let title = title_b.to_string()
              let t = if title.length() > 0 { Some(title) } else { None }
              let url = url_b.to_string()
              return (
                Image(inlines_to_raw_text(alt_text), url, t),
                advance(title_cur),
              )
            }
            break
          }
          title_b.write_string(
            String::make(1, peek(title_cur).unwrap()),
          )
          title_cur = advance(title_cur)
        }
        url_b.write_string(" ")
      } else {
        url_b.write_string(" ")
        cur = after_space
      }
    } else {
      url_b.write_string(String::make(1, c))
      cur = advance(cur)
    }
  }

  if peek(cur).is_some() && peek(cur).unwrap() == ')' {
    (Image(inlines_to_raw_text(alt_text), url_b.to_string(), None), advance(cur))
  } else {
    (Text("![" + inlines_to_raw_text(alt_text) + "](" + url_b.to_string()), cur)
  }
}

fn inlines_to_raw_text(inlines : Array[Inline]) -> String {
  let sb = StringBuilder::new()
  let mut i = 0
  while i < inlines.length() {
    let inline = inlines[i]
    match inline {
      Text(s) => sb.write_string(s)
      SoftBreak => sb.write_string("\n")
      HardBreak => sb.write_string("  \n")
      Emphasis(children) => {
        sb.write_string("*")
        sb.write_string(inlines_to_raw_text(children))
        sb.write_string("*")
      }
      Strong(children) => {
        sb.write_string("**")
        sb.write_string(inlines_to_raw_text(children))
        sb.write_string("**")
      }
      Code(code) => {
        sb.write_string("`")
        sb.write_string(code)
        sb.write_string("`")
      }
      Link(text, url, title) => {
        sb.write_string("[")
        sb.write_string(inlines_to_raw_text(text))
        sb.write_string("](")
        sb.write_string(url)
        if title.is_some() {
          sb.write_string(" \"")
          sb.write_string(title.unwrap())
          sb.write_string("\"")
        }
        sb.write_string(")")
      }
      Image(alt, url, title) => {
        sb.write_string("![")
        sb.write_string(alt)
        sb.write_string("](")
        sb.write_string(url)
        if title.is_some() {
          sb.write_string(" \"")
          sb.write_string(title.unwrap())
          sb.write_string("\"")
        }
        sb.write_string(")")
      }
    }
    i = i + 1
  }
  sb.to_string()
}
