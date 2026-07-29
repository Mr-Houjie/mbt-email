/// TOML lexer: tokenizes TOML source text into tokens.

/// Token types for TOML parsing.
pub enum Token {
  Key(String)       // bare key: [A-Za-z0-9_-]+
  String_(String)   // quoted string
  Integer(Int)      // integer literal
  Float(Double)     // float literal
  Bool(Bool)        // true or false
  Equals            // =
  Dot               // .
  Comma             // ,
  LBracket          // [
  RBracket          // ]
  LBrace            // {
  RBrace            // }
  DoubleLBracket    // [[
  DoubleRBracket    // ]]
  Newline
  EOF
}

struct Lexer {
  input : String
  pos : Int
  len : Int
}

fn Lexer::new(input : String) -> Lexer {
  { input, pos: 0, len: input.length() }
}

fn peek(l : Lexer, offset : Int) -> Char? {
  l.input.get_char(l.pos + offset)
}

fn advance(l : Lexer) -> Lexer {
  { input: l.input, pos: l.pos + 1, len: l.len }
}

fn skip_whitespace_and_comments(l : Lexer) -> Lexer {
  let mut cur = l
  while true {
    if cur.pos >= cur.len {
      break
    }
    let c = cur.input.unsafe_char_at(cur.pos)
    if c == ' ' || c == '\t' || c == '\r' {
      cur = advance(cur)
    } else if c == '#' {
      while cur.pos < cur.len && cur.input.unsafe_char_at(cur.pos) != '\n' {
        cur = advance(cur)
      }
    } else {
      break
    }
  }
  cur
}

/// Tokenize the input and return all tokens.
pub fn tokenize(input : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let mut l = Lexer::new(input)

  while l.pos < l.len {
    l = skip_whitespace_and_comments(l)
    if l.pos >= l.len {
      break
    }

    let c = l.input.unsafe_char_at(l.pos)

    if c == '\n' {
      tokens.push(Newline)
      l = advance(l)
      continue
    }

    if c == '=' {
      tokens.push(Equals)
      l = advance(l)
      continue
    }
    if c == '.' {
      tokens.push(Dot)
      l = advance(l)
      continue
    }
    if c == ',' {
      tokens.push(Comma)
      l = advance(l)
      continue
    }
    if c == '{' {
      tokens.push(LBrace)
      l = advance(l)
      continue
    }
    if c == '}' {
      tokens.push(RBrace)
      l = advance(l)
      continue
    }

    // Brackets: [] or [[ or ]]
    if c == '[' {
      let nxt = peek(l, 1)
      if nxt.is_some() && nxt.unwrap() == '[' {
        tokens.push(DoubleLBracket)
        l = advance(advance(l))
      } else {
        tokens.push(LBracket)
        l = advance(l)
      }
      continue
    }
    if c == ']' {
      let nxt = peek(l, 1)
      if nxt.is_some() && nxt.unwrap() == ']' {
        tokens.push(DoubleRBracket)
        l = advance(advance(l))
      } else {
        tokens.push(RBracket)
        l = advance(l)
      }
      continue
    }

    // Strings: "basic" or 'literal' or """multiline""" or '''multiline literal'''
    if c == '"' {
      let nxt1 = peek(l, 1)
      let nxt2 = peek(l, 2)
      let multiline = nxt1.is_some() && nxt1.unwrap() == '"' &&
                      nxt2.is_some() && nxt2.unwrap() == '"'
      if multiline {
        let (s, after) = scan_multi_line_string(advance(advance(advance(l))))
        tokens.push(String_(s))
        l = after
      } else {
        let (s, after) = scan_basic_string(advance(l))
        tokens.push(String_(s))
        l = after
      }
      continue
    }
    if c == '\'' {
      let nxt1 = peek(l, 1)
      let nxt2 = peek(l, 2)
      let multiline = nxt1.is_some() && nxt1.unwrap() == '\'' &&
                      nxt2.is_some() && nxt2.unwrap() == '\''
      if multiline {
        let (s, after) = scan_multi_line_literal(advance(advance(advance(l))))
        tokens.push(String_(s))
        l = after
      } else {
        let (s, after) = scan_literal_string(advance(l))
        tokens.push(String_(s))
        l = after
      }
      continue
    }

    // booleans: true / false
    if is_key_char(c) {
      let (word, after) = scan_bare_key_or_bool(l)
      if word == "true" {
        tokens.push(Bool(true))
      } else if word == "false" {
        tokens.push(Bool(false))
      } else {
        tokens.push(Key(word))
      }
      l = after
      continue
    }

    // Numbers: integers and floats, including +/- prefix
    if is_digit(c) || ((c == '+' || c == '-') &&
        nxt_digit(l)) {
      let (token, after) = scan_number(l)
      tokens.push(token)
      l = after
      continue
    }

    l = advance(l)
  }

  tokens.push(EOF)
  tokens
}

fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

fn is_key_char(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
  is_digit(c) || c == '_' || c == '-'
}

fn nxt_digit(l : Lexer) -> Bool {
  let nxt = peek(l, 1)
  nxt.is_some() && is_digit(nxt.unwrap())
}

fn scan_bare_key_or_bool(l : Lexer) -> (String, Lexer) {
  let mut cur = l
  let sb = StringBuilder::new()
  while cur.pos < cur.len {
    let c = cur.input.unsafe_char_at(cur.pos)
    if !is_key_char(c) {
      break
    }
    sb.write_string(String::make(1, c))
    cur = advance(cur)
  }
  (sb.to_string(), cur)
}

fn scan_basic_string(l : Lexer) -> (String, Lexer) {
  let mut cur = l
  let sb = StringBuilder::new()
  while cur.pos < cur.len {
    let c = cur.input.unsafe_char_at(cur.pos)
    if c == '"' {
      cur = advance(cur)
      break
    }
    if c == '\\' {
      cur = advance(cur)
      if cur.pos < cur.len {
        let escaped = cur.input.unsafe_char_at(cur.pos)
        match escaped {
          'b' => sb.write_string("\b")
          't' => sb.write_string("\t")
          'n' => sb.write_string("\n")
          'f' => sb.write_string("\f")
          'r' => sb.write_string("\r")
          '"' => sb.write_string("\"")
          '\\' => sb.write_string("\\")
          _ => sb.write_string(String::make(1, escaped))
        }
        cur = advance(cur)
      }
    } else {
      sb.write_string(String::make(1, c))
      cur = advance(cur)
    }
  }
  (sb.to_string(), cur)
}

fn scan_multi_line_string(l : Lexer) -> (String, Lexer) {
  let mut cur = l
  let sb = StringBuilder::new()
  // Skip leading newline if present
  if cur.pos < cur.len && cur.input.unsafe_char_at(cur.pos) == '\n' {
    cur = advance(cur)
  }
  while cur.pos < cur.len {
    let c = cur.input.unsafe_char_at(cur.pos)
    if c == '"' {
      let n1 = peek(cur, 1)
      let n2 = peek(cur, 2)
      if n1.is_some() && n1.unwrap() == '"' &&
         n2.is_some() && n2.unwrap() == '"' {
        cur = advance(advance(advance(cur)))
        break
      }
    }
    if c == '\\' {
      cur = advance(cur)
      if cur.pos < cur.len {
        let escaped = cur.input.unsafe_char_at(cur.pos)
        if escaped == '\n' || escaped == '\r' {
          cur = advance(cur)
          continue
        }
        sb.write_string("\\")
        sb.write_string(String::make(1, escaped))
        cur = advance(cur)
      }
    } else {
      sb.write_string(String::make(1, c))
      cur = advance(cur)
    }
  }
  (sb.to_string(), cur)
}

fn scan_literal_string(l : Lexer) -> (String, Lexer) {
  let mut cur = l
  let sb = StringBuilder::new()
  while cur.pos < cur.len {
    let c = cur.input.unsafe_char_at(cur.pos)
    if c == '\'' {
      cur = advance(cur)
      break
    }
    sb.write_string(String::make(1, c))
    cur = advance(cur)
  }
  (sb.to_string(), cur)
}

fn scan_multi_line_literal(l : Lexer) -> (String, Lexer) {
  let mut cur = l
  let sb = StringBuilder::new()
  if cur.pos < cur.len && cur.input.unsafe_char_at(cur.pos) == '\n' {
    cur = advance(cur)
  }
  while cur.pos < cur.len {
    let c = cur.input.unsafe_char_at(cur.pos)
    if c == '\'' {
      let n1 = peek(cur, 1)
      let n2 = peek(cur, 2)
      if n1.is_some() && n1.unwrap() == '\'' &&
         n2.is_some() && n2.unwrap() == '\'' {
        cur = advance(advance(advance(cur)))
        break
      }
    }
    sb.write_string(String::make(1, c))
    cur = advance(cur)
  }
  (sb.to_string(), cur)
}

fn scan_number(l : Lexer) -> (Token, Lexer) {
  let mut cur = l
  let sb = StringBuilder::new()

  // Optional sign
  let c0 = cur.input.unsafe_char_at(cur.pos)
  if c0 == '+' || c0 == '-' {
    sb.write_string(String::make(1, c0))
    cur = advance(cur)
  }

  // Check for special float values: inf, nan
  let remaining = cur.len - cur.pos
  if remaining >= 3 {
    let word = scan_word(cur)
    if word == "inf" {
      sb.write_string("inf")
      cur = advance(advance(advance(cur)))
      let value = sb.to_string().to_double()
      return (Float(value), cur)
    }
    if word == "nan" {
      sb.write_string("nan")
      cur = advance(advance(advance(cur)))
      let value = sb.to_string().to_double()
      return (Float(value), cur)
    }
  }

  // Check for hex/octal/binary prefix (only for positive integers)
  if cur.pos < cur.len {
    let c = cur.input.unsafe_char_at(cur.pos)
    if c == '0' {
      sb.write_string("0")
      cur = advance(cur)
      if cur.pos < cur.len {
        let next_c = cur.input.unsafe_char_at(cur.pos)
        if next_c == 'x' || next_c == 'o' || next_c == 'b' {
          sb.write_string(String::make(1, next_c))
          cur = advance(cur)
          while cur.pos < cur.len {
            let dc = cur.input.unsafe_char_at(cur.pos)
            if is_digit(dc) || (dc >= 'a' && dc <= 'f') ||
               (dc >= 'A' && dc <= 'F') || dc == '_' {
              if dc != '_' {
                sb.write_string(String::make(1, dc))
              }
              cur = advance(cur)
            } else {
              break
            }
          }
          let num_str = sb.to_string()
          // Parse non-decimal integer
          let mut value : Int = 0
          let mut i = 2
          let base = match next_c {
            'x' => 16
            'o' => 8
            _ => 2
          }
          while i < num_str.length() {
            let dc = num_str.unsafe_char_at(i)
            let digit = if dc >= '0' && dc <= '9' {
              dc.to_int() - 48
            } else if dc >= 'a' && dc <= 'f' {
              dc.to_int() - 87
            } else {
              dc.to_int() - 55
            }
            value = value * base + digit
            i = i + 1
          }
          return (Integer(value), cur)
        }
      }
    }
  }

  // Parse integer/float digits
  let mut has_dot = false
  let mut has_exp = false
  while cur.pos < cur.len {
    let c = cur.input.unsafe_char_at(cur.pos)
    if is_digit(c) || c == '_' {
      if c != '_' {
        sb.write_string(String::make(1, c))
      }
      cur = advance(cur)
    } else if c == '.' && !has_dot && !has_exp {
      has_dot = true
      sb.write_string(".")
      cur = advance(cur)
    } else if (c == 'e' || c == 'E') && !has_exp {
      has_exp = true
      sb.write_string(String::make(1, c))
      cur = advance(cur)
      if cur.pos < cur.len {
        let ec = cur.input.unsafe_char_at(cur.pos)
        if ec == '+' || ec == '-' {
          sb.write_string(String::make(1, ec))
          cur = advance(cur)
        }
      }
    } else {
      break
    }
  }

  let num_str = sb.to_string()
  if has_dot || has_exp {
    (Float(num_str.to_double()), cur)
  } else {
    (Integer(num_str.to_int()), cur)
  }
}

fn scan_word(l : Lexer) -> String {
  let mut cur = l
  let sb = StringBuilder::new()
  let mut i = 0
  while i < 3 && cur.pos < cur.len {
    let c = cur.input.unsafe_char_at(cur.pos)
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
      sb.write_string(String::make(1, c))
      cur = advance(cur)
    } else {
      break
    }
    i = i + 1
  }
  sb.to_string()
}
