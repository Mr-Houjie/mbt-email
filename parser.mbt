/// Block-level Markdown parser.
struct LineIter {
  lines : Array[String]
  pos : Int
}

fn LineIter::new(s : String) -> LineIter {
  { lines: split_lines(s), pos: 0 }
}

fn peek_line(iter : LineIter) -> String? {
  if iter.pos < iter.lines.length() {
    Some(iter.lines[iter.pos])
  } else {
    None
  }
}

fn advance_line(iter : LineIter) -> LineIter {
  { lines: iter.lines, pos: iter.pos + 1 }
}

fn split_lines(s : String) -> Array[String] {
  let result : Array[String] = []
  let mut i = 0
  let len = s.length()
  let mut start = 0
  while i < len {
    if s[i] == '\n' {
      result.push(s.substring(start~, end=i))
      start = i + 1
    }
    i = i + 1
  }
  if start < len {
    result.push(s.substring(start~, end=len))
  } else if len > 0 && s[len - 1] == '\n' {
    result.push("")
  }
  result
}

/// Parse a full Markdown document string into an AST
pub fn parse_document(input : String) -> Document {
  let iter = LineIter::new(input)
  let blocks = parse_blocks(iter)
  { blocks, }
}

fn parse_blocks(iter : LineIter) -> Array[Block] {
  let blocks : Array[Block] = []
  let mut cur = iter

  while true {
    let line_opt = peek_line(cur)
    if line_opt.is_none() {
      break
    }
    let trimmed = trim_left(line_opt.unwrap())

    if trimmed.length() == 0 {
      cur = advance_line(cur)
      continue
    }

    // Thematic break
    if is_thematic_break(trimmed) {
      blocks.push(ThematicBreak)
      cur = advance_line(cur)
      continue
    }

    // ATX heading
    let heading_level = heading_match(trimmed)
    if heading_level > 0 {
      let content_raw = trimmed.substring(
        start=heading_level,
        end=trimmed.length(),
      )
      let content_trimmed = content_raw.trim().to_string()
      let inlines = parse_inlines(content_trimmed)
      blocks.push(Heading(heading_level, inlines))
      cur = advance_line(cur)
      continue
    }

    // Fenced code block
    let fence_info = fence_code_match(trimmed)
    if fence_info.is_some() {
      let (fence_char, fence_len, lang) = fence_info.unwrap()
      let (code_content, after_code) = parse_fenced_code(
        advance_line(cur),
        fence_char,
        fence_len,
      )
      blocks.push(
        CodeBlock(
          if lang.length() > 0 {
            Some(lang)
          } else {
            None
          },
          code_content,
        ),
      )
      cur = after_code
      continue
    }

    // Blockquote
    if trimmed.length() >= 2 && trimmed[0] == '>' && trimmed[1] == ' ' {
      let (quote_blocks, after_quote) = parse_blockquote(cur)
      blocks.push(Blockquote(quote_blocks))
      cur = after_quote
      continue
    }
    if trimmed == ">" {
      let (quote_blocks, after_quote) = parse_blockquote(cur)
      blocks.push(Blockquote(quote_blocks))
      cur = after_quote
      continue
    }

    // List items
    let list_info = list_item_match(trimmed)
    if list_info.is_some() {
      let (mode, items, after_list) = parse_list(cur, list_info.unwrap())
      blocks.push(ListBlock(mode, items))
      cur = after_list
      continue
    }

    // Default: paragraph
    let (para_blocks, after_para) = parse_paragraph(cur)
    let mut pi = 0
    while pi < para_blocks.length() {
      blocks.push(para_blocks[pi])
      pi = pi + 1
    }
    cur = after_para
  }

  blocks
}

fn is_thematic_break(line : String) -> Bool {
  let len = line.length()
  if len < 3 {
    return false
  }
  let first_char = line.unsafe_char_at(0)
  if first_char != '-' && first_char != '*' && first_char != '_' {
    return false
  }

  let mut count = 0
  let mut i = 0
  while i < len {
    let c = line.unsafe_char_at(i)
    if c == ' ' || c == '\t' {
      i = i + 1
    } else if c == first_char {
      count = count + 1
      i = i + 1
    } else {
      return false
    }
  }
  count >= 3
}

fn heading_match(line : String) -> Int {
  let len = line.length()
  let mut i = 0
  while i < len && line.unsafe_char_at(i) == '#' {
    i = i + 1
  }
  if i >= 1 && i <= 6 {
    if i >= len || line.unsafe_char_at(i) == ' ' {
      return i
    }
  }
  0
}

fn fence_code_match(line : String) -> (Char, Int, String)? {
  let trimmed = trim_left(line)
  let len = trimmed.length()
  if len < 3 {
    return None
  }
  let first_char = trimmed.unsafe_char_at(0)
  if first_char != '`' && first_char != '~' {
    return None
  }

  let mut count = 1
  while count < len && trimmed.unsafe_char_at(count) == first_char {
    count = count + 1
  }

  if count < 3 {
    return None
  }

  let lang = if count < len {
    trimmed.substring(start=count, end=len).trim().to_string()
  } else {
    ""
  }
  Some((first_char, count, lang))
}

fn parse_fenced_code(
  iter : LineIter,
  fence_char : Char,
  fence_len : Int,
) -> (String, LineIter) {
  let code_lines : Array[String] = []
  let mut cur = iter

  while true {
    let line_opt = peek_line(cur)
    if line_opt.is_none() {
      break
    }
    let line = line_opt.unwrap()
    let trimmed = trim_left(line)
    let tlen = trimmed.length()

    // Check for closing fence
    let mut is_closing = false
    if tlen >= fence_len {
      let first = trimmed.unsafe_char_at(0)
      if first == fence_char {
        let mut cnt = 1
        while cnt < tlen && trimmed.unsafe_char_at(cnt) == fence_char {
          cnt = cnt + 1
        }
        is_closing = cnt >= fence_len
      }
    }

    if is_closing {
      cur = advance_line(cur)
      break
    }

    code_lines.push(line)
    cur = advance_line(cur)
  }

  (code_lines.join("\n"), cur)
}

fn parse_blockquote(iter : LineIter) -> (Array[Block], LineIter) {
  let quote_lines : Array[String] = []
  let mut cur = iter

  while true {
    let line_opt = peek_line(cur)
    if line_opt.is_none() {
      break
    }
    let trimmed = trim_left(line_opt.unwrap())
    if trimmed.length() >= 2 &&
      trimmed.unsafe_char_at(0) == '>' &&
      trimmed.unsafe_char_at(1) == ' ' {
      quote_lines.push(trimmed.substring(start=2, end=trimmed.length()))
      cur = advance_line(cur)
    } else if trimmed == ">" {
      quote_lines.push("")
      cur = advance_line(cur)
    } else if trimmed.length() >= 1 && trimmed.unsafe_char_at(0) == '>' {
      quote_lines.push(trimmed.substring(start=1, end=trimmed.length()))
      cur = advance_line(cur)
    } else {
      break
    }
  }

  let joined = quote_lines.join("\n")
  (parse_blocks(LineIter::new(joined)), cur)
}

struct ListMatch {
  mode : ListMode
  content : String
}

fn list_item_match(line : String) -> ListMatch? {
  let trimmed = line.trim().to_string()
  let len = trimmed.length()

  // Unordered list: -, *, +
  if len >= 2 {
    let c = trimmed.unsafe_char_at(0)
    if (c == '-' || c == '*' || c == '+') && trimmed.unsafe_char_at(1) == ' ' {
      return Some({
        mode: Bullet(String::make(1, c)),
        content: trimmed.substring(start=2, end=len),
      })
    }
  }

  // Ordered list: 1. item
  let mut i = 0
  while i < len &&
        trimmed.unsafe_char_at(i) >= '0' &&
        trimmed.unsafe_char_at(i) <= '9' {
    i = i + 1
  }
  if i > 0 && i < len {
    let after_num = trimmed.unsafe_char_at(i)
    if after_num == '.' || after_num == ')' {
      // Parse number
      let mut num = 0
      let mut j = 0
      while j < i {
        num = num * 10 + (trimmed.unsafe_char_at(j).to_int() - 48)
        j = j + 1
      }
      if num < 1 {
        num = 1
      }
      let content_start = i + 1
      let content = if content_start < len {
        if trimmed.unsafe_char_at(content_start) == ' ' {
          trimmed.substring(start=content_start + 1, end=len)
        } else {
          trimmed.substring(start=content_start, end=len)
        }
      } else {
        ""
      }
      return Some({
        mode: Ordered(num),
        content,
      })
    }
  }

  None
}

fn parse_list(
  iter : LineIter,
  first_match : ListMatch,
) -> (ListMode, Array[ListItem], LineIter) {
  let mode = first_match.mode
  let items : Array[ListItem] = []
  let mut cur = iter

  // Process first item
  let (first_item_lines, after_first) = collect_list_item_lines(
    advance_line(cur),
    first_match.content,
  )
  items.push(parse_list_item_lines(first_item_lines))
  cur = after_first

  // Process remaining items
  while true {
    let line_opt = peek_line(cur)
    if line_opt.is_none() {
      break
    }
    let lm = list_item_match(line_opt.unwrap())
    if lm.is_some() {
      let m = lm.unwrap()
      let same_mode = match (mode, m.mode) {
        (Bullet(_), Bullet(_)) => true
        (Ordered(_), Ordered(_)) => true
        _ => false
      }
      if !same_mode {
        break
      }
      let (item_lines, after_item) = collect_list_item_lines(
        advance_line(cur),
        m.content,
      )
      items.push(parse_list_item_lines(item_lines))
      cur = after_item
    } else {
      break
    }
  }

  (mode, items, cur)
}

fn collect_list_item_lines(
  iter : LineIter,
  first_content : String,
) -> (Array[String], LineIter) {
  let lines : Array[String] = [first_content]
  let mut cur = iter

  while true {
    let line_opt = peek_line(cur)
    if line_opt.is_none() {
      break
    }
    let line = line_opt.unwrap()
    let trimmed = trim_left(line)
    if trimmed.length() == 0 {
      break
    }
    if list_item_match(line).is_some() {
      break
    }
    let leading_spaces = line.length() - trimmed.length()
    if leading_spaces >= 2 {
      lines.push(trimmed)
      cur = advance_line(cur)
    } else {
      break
    }
  }

  (lines, cur)
}

fn parse_list_item_lines(lines : Array[String]) -> ListItem {
  let joined = lines.join("\n")
  let blocks = parse_blocks(LineIter::new(joined))
  { blocks, checked: None }
}

fn parse_paragraph(iter : LineIter) -> (Array[Block], LineIter) {
  let para_lines : Array[String] = []
  let mut cur = iter

  while true {
    let line_opt = peek_line(cur)
    if line_opt.is_none() {
      break
    }
    let trimmed = trim_left(line_opt.unwrap())
    if trimmed.length() == 0 {
      break
    }

    if heading_match(trimmed) > 0 ||
      is_thematic_break(trimmed) ||
      fence_code_match(trimmed).is_some() ||
      (
        trimmed.length() >= 2 &&
        trimmed.unsafe_char_at(0) == '>' &&
        trimmed.unsafe_char_at(1) == ' '
      ) ||
      trimmed == ">" ||
      list_item_match(trimmed).is_some() {
      break
    }
    para_lines.push(trimmed)
    cur = advance_line(cur)
  }

  let text = para_lines.join("\n")
  let inlines = parse_inlines(text)
  ([Paragraph(inlines)], cur)
}

fn trim_left(s : String) -> String {
  let mut i = 0
  let len = s.length()
  while i < len && (s[i] == ' ' || s[i] == '\t') {
    i = i + 1
  }
  if i >= len {
    ""
  } else {
    s.substring(start=i, end=len)
  }
}
