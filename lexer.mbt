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
      if opt_char_eq(peek(l, 1), '[') {
        tokens.push(DoubleLBracket)
        l = advance(advance(l))
      } else {
        tokens.push(LBracket)
        l = advance(l)
      }
      continue
    }
    if c == ']' {
      if opt_char_eq(peek(l, 1), ']') {
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
      let multiline = opt_char_eq(peek(l, 1), '"') &&
                      opt_char_eq(peek(l, 2), '"')
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
      let multiline = opt_char_eq(peek(l, 1), '\'') &&
                      opt_char_eq(peek(l, 2), '\'')
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

    // Numbers: integers and floats, including +/- prefix
    if is_digit(c) || ((c == '+' || c == '-') &&
        nxt_digit(l)) {
      let (token, after) = scan_number(l)
      tokens.push(token)
      l = after
      continue
    }

    // booleans: true / false, bare keys
    if is_key_start_char(c) {
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

fn is_key_start_char(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_'
}

/// Helper: check if an optional char matches a given char.
fn opt_char_eq(opt : Char?, expected : Char) -> Bool {
  match opt {
    Some(c) => c == expected
    None => false
  }
}

fn nxt_digit(l : Lexer) -> Bool {
  match peek(l, 1) {
    Some(c) => is_digit(c)
    None => false
  }
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
      if opt_char_eq(peek(cur, 1), '"') &&
         opt_char_eq(peek(cur, 2), '"') {
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
      if opt_char_eq(peek(cur, 1), '\'') &&
         opt_char_eq(peek(cur, 2), '\'') {
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
      cur = advance(advance(advance(cur)))
      return (Float(0.0), cur)
    }
    if word == "nan" {
      cur = advance(advance(advance(cur)))
      return (Float(0.0), cur)
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

  // Parse integer/float digits (decimal)
  let mut int_value : Int = 0
  let mut has_dot = false
  let mut has_exp = false
  let mut frac_value : Int = 0
  let mut frac_digits : Int = 0
  while cur.pos < cur.len {
    let c = cur.input.unsafe_char_at(cur.pos)
    if is_digit(c) {
      if has_dot {
        frac_value = frac_value * 10 + (c.to_int() - 48)
        frac_digits = frac_digits + 1
      } else {
        int_value = int_value * 10 + (c.to_int() - 48)
      }
      cur = advance(cur)
    } else if c == '_' {
      cur = advance(cur)
    } else if c == '.' && !has_dot && !has_exp {
      has_dot = true
      cur = advance(cur)
    } else if (c == 'e' || c == 'E') && !has_exp {
      has_exp = true
      cur = advance(cur)
      if cur.pos < cur.len {
        let ec = cur.input.unsafe_char_at(cur.pos)
        if ec == '+' || ec == '-' {
          cur = advance(cur)
        }
      }
      while cur.pos < cur.len && is_digit(cur.input.unsafe_char_at(cur.pos)) {
        cur = advance(cur)
      }
    } else {
      break
    }
  }

  if has_dot || has_exp {
    let mut dbl : Double = int_value.to_double()
    if has_dot && frac_digits > 0 {
      let mut frac_div : Double = 1.0
      let mut fi = 0
      while fi < frac_digits {
        frac_div = frac_div * 10.0
        fi = fi + 1
      }
      dbl = dbl + frac_value.to_double() / frac_div
    }
    (Float(dbl), cur)
  } else {
    (Integer(int_value), cur)
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
