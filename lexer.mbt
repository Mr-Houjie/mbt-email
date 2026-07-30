/// Email/MIME lexer: tokenizes raw email text into tokens for parsing.
///
/// Handles RFC 5322 message format tokens including header names,
/// quoted strings, domain literals, atoms, and special characters.

/// Token types for email/MIME lexing.
pub enum Token {
  /// A header field name (e.g., "From", "To", "Subject").
  HeaderName(String)
  /// A header field body value (unfolded).
  HeaderValue(String)
  /// @ sign
  AtSign
  /// . (dot)
  Dot
  /// , (comma)
  Comma
  /// ; (semicolon)
  Semicolon
  /// : (colon)
  Colon
  /// = (equals)
  Equals
  /// < (left angle bracket)
  LAngle
  /// > (right angle bracket)
  RAngle
  /// [ (left bracket)
  LBracket
  /// ] (right bracket)
  RBracket
  /// ( (left paren)
  LParen
  /// ) (right paren)
  RParen
  /// / (slash)
  Slash
  /// A quoted string value (including the quotes)
  QuotedString(String)
  /// An unquoted atom (alphanumeric word or symbol sequence)
  Atom(String)
  /// A domain literal [1.2.3.4] or [IPv6:...]
  DomainLiteral(String)
  /// A newline (CRLF or LF)
  Newline
  /// End of input
  EOF
  /// A MIME boundary line (e.g., "--boundary" or "--boundary--")
  Boundary(String)
}

/// The lexer state.
struct Lexer {
  input : String
  pos : Int
  len : Int
}

fn Lexer::new(input : String) -> Lexer {
  Lexer::{ input, pos: 0, len: input.length() }
}

/// Peek at current character without consuming.
fn peek(l : Lexer) -> Char? {
  if l.pos < l.len {
    Some(l.input.get_char(l.pos).unwrap())
  } else {
    None
  }
}

/// Peek at character at offset from current position.
fn peek_at(l : Lexer, offset : Int) -> Char? {
  let idx = l.pos + offset
  if idx < l.len {
    Some(l.input.get_char(idx).unwrap())
  } else {
    None
  }
}

/// Advance and return current character.
fn advance(l : Lexer) -> Lexer {
  Lexer::{ input: l.input, pos: l.pos + 1, len: l.len }
}

/// Advance by n characters.
fn advance_n(l : Lexer, n : Int) -> Lexer {
  Lexer::{ input: l.input, pos: l.pos + n, len: l.len }
}

/// Check if character is whitespace (space or tab).
fn is_wsp(c : Char) -> Bool {
  c == ' ' || c == '\t'
}

/// Check if character is a letter (a-z, A-Z).
fn is_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

/// Check if character is a digit (0-9).
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

/// Check if character is valid in an atom.
fn is_atext(c : Char) -> Bool {
  is_alpha(c) || is_digit(c) ||
  c == '!' || c == '#' || c == '$' || c == '%' || c == '&' ||
  c == '\'' || c == '*' || c == '+' || c == '-' || c == '/' ||
  c == '=' || c == '?' || c == '^' || c == '_' || c == '`' ||
  c == '{' || c == '|' || c == '}' || c == '~'
}

/// Check if character is valid in a header name.
fn is_header_name_char(c : Char) -> Bool {
  is_alpha(c) || is_digit(c) || c == '-'
}

/// Check for CR (carriage return).
fn is_cr(l : Lexer) -> Bool {
  match peek(l) {
    Some('\r') => true
    _ => false
  }
}

/// Check for LF (line feed).
fn is_lf(l : Lexer) -> Bool {
  match peek(l) {
    Some('\n') => true
    _ => false
  }
}

/// Skip a CRLF or LF newline sequence. Returns new lexer position.
fn skip_newline(l : Lexer) -> Lexer {
  let mut cur = l
  match peek(cur) {
    Some('\r') => cur = advance(cur)
    _ => ()
  }
  match peek(cur) {
    Some('\n') => {
      cur = advance(cur)
      // Detect boundary lines: check if the next line starts with "--"
      // Boundary detection is done at the caller level
    }
    _ => ()
  }
  cur
}

/// Skip whitespace (space and tab).
fn skip_wsp(l : Lexer) -> Lexer {
  let mut cur = l
  while true {
    match peek(cur) {
      Some(c) if is_wsp(c) => cur = advance(cur)
      _ => break
    }
  }
  cur
}

/// Read an atom (sequence of atext characters).
fn read_atom(l : Lexer) -> (String, Lexer) {
  let start = l.pos
  let mut cur = l
  while true {
    match peek(cur) {
      Some(c) if is_atext(c) => cur = advance(cur)
      _ => break
    }
  }
  let value = l.input.unsafe_substring(start=start, end=cur.pos)
  (value, cur)
}

/// Read a header name (sequence of alphanumeric or hyphen).
fn read_header_name(l : Lexer) -> (String, Lexer) {
  let start = l.pos
  let mut cur = l
  while true {
    match peek(cur) {
      Some(c) if is_header_name_char(c) => cur = advance(cur)
      _ => break
    }
  }
  (l.input.unsafe_substring(start=start, end=cur.pos), cur)
}

/// Read a quoted string (including the surrounding double quotes).
/// Returns the full string including quotes.
fn read_quoted_string(l : Lexer) -> (String, Lexer) {
  let mut cur = advance(l) // skip opening quote
  let start = l.pos  // start after opening quote
  while true {
    match peek(cur) {
      None => break  // unterminated, return what we have
      Some('\\') => {
        cur = advance(cur) // skip backslash
        match peek(cur) {
          Some(_) => cur = advance(cur) // skip escaped char
          None => break
        }
      }
      Some('"') => {
        cur = advance(cur) // skip closing quote
        break
      }
      Some(_) => cur = advance(cur)
    }
  }
  // Return the full quoted string including quotes
  (l.input.unsafe_substring(start=l.pos, end=cur.pos), cur)
}

/// Read a domain literal (e.g., [127.0.0.1] or [IPv6:...]).
fn read_domain_literal(l : Lexer) -> (String, Lexer) {
  let mut cur = advance(l) // skip [
  let start = l.pos
  let mut depth = 1
  while depth > 0 {
    match peek(cur) {
      None => break
      Some('[') => { depth = depth + 1; cur = advance(cur) }
      Some(']') => { depth = depth - 1; if depth > 0 { cur = advance(cur) } }
      Some('\\') => { cur = advance(cur); match peek(cur) { Some(_) => cur = advance(cur); None => () } }
      Some(_) => cur = advance(cur)
    }
  }
  let content = l.input.unsafe_substring(start=start, end=cur.pos)
  if depth == 0 {
    cur = advance(cur) // skip closing ]
  }
  (content, cur)
}


/// Read a header field value, handling folding (continuation lines starting with WSP).
/// Stops at CRLF that is NOT followed by WSP.
/// Also detects MIME boundary lines (starting with "--").
fn read_header_value(l : Lexer) -> (String, Lexer) {
  let mut cur = l
  let buf = StringBuilder::new()

  while true {
    match peek(cur) {
      None => break
      Some('\r') | Some('\n') => {
        // Save current position before the newline
        let pre_nl = cur
        cur = skip_newline(cur)
        // Check for folding: next char is WSP
        match peek(cur) {
          Some(c) if is_wsp(c) => {
            // Folding: replace CRLF with space in unfolded value
            buf.write_char(' ')
            cur = skip_wsp(cur)
            continue
          }
          _ => {
            // Not folding, rewind to before the newline
            cur = pre_nl
            break
          }
        }
      }
      Some(c) => {
        buf.write_char(c)
        cur = advance(cur)
      }
    }
  }
  (buf.to_string().trim_end(chars=" \t").to_string(), cur)
}

/// Read a boundary line: lines starting with "--".
/// Returns the boundary string and whether it's a closing boundary.
fn read_boundary(l : Lexer) -> (String, Bool, Lexer) {
  let mut cur = advance_n(l, 2) // skip "--"
  let start = cur.pos
  // Read until end of line or end of input
  let buf = StringBuilder::new()
  while true {
    match peek(cur) {
      None => break
      Some('\r') | Some('\n') => break
      Some(c) => {
        buf.write_char(c)
        cur = advance(cur)
      }
    }
  }
  let line = buf.to_string()
  let is_close = line.has_suffix("--")
  let boundary = if is_close {
    line.unsafe_substring(start=0, end=line.length() - 2)
  } else {
    line
  }
  // Skip trailing newline
  cur = skip_newline(cur)
  (boundary, is_close, cur)
}


/// Tokenize the entire input into a sequence of tokens.
/// This is the main entry point for the lexer.
pub fn tokenize(input : String) -> Array[Token] {
  let l = Lexer::new(input)
  let tokens : Array[Token] = []
  let mut cur = l

  while cur.pos < cur.len {
    match peek(cur) {
      None => break

      // Newlines
      Some('\r') | Some('\n') => {
        tokens.push(Newline)
        cur = skip_newline(cur)
      }

      // Whitespace (only significant at certain positions; mostly skip)
      Some(c) if is_wsp(c) => {
        cur = skip_wsp(cur)
      }

      // Boundary line detection: line starting with "--"
      Some('-') => {
        match peek_at(cur, 1) {
          Some('-') => {
            let (boundary, is_close, after) = read_boundary(cur)
            let token_str = if is_close {
              "--" + boundary + "--"
            } else {
              "--" + boundary
            }
            tokens.push(Boundary(token_str))
            cur = after
          }
          _ => {
            // Just a dash, read as atom
            let (atom, after) = read_atom(cur)
            tokens.push(Atom(atom))
            cur = after
          }
        }
      }

      // Header name detection: alpha char at start of line or after newline
      // We detect header names by checking if we're at the start of a line
      // and the next token looks like "Name:"
      Some(c) if is_alpha(c) => {
        // Peek ahead to see if this is a header name (followed by colon)
        let (name, after_name) = read_header_name(cur)
        let after_wsp = skip_wsp(after_name)
        match peek(after_wsp) {
          Some(':') => {
            tokens.push(HeaderName(name))
            cur = after_wsp
            tokens.push(Colon)
            cur = advance(cur) // skip colon
            cur = skip_wsp(cur) // skip optional whitespace after colon
            let (value, after_value) = read_header_value(cur)
            tokens.push(HeaderValue(value))
            cur = after_value
          }
          _ => {
            // Not a header, it's an atom
            tokens.push(Atom(name))
            cur = after_name
          }
        }
      }

      // Special characters
      Some('@') => { tokens.push(AtSign); cur = advance(cur) }
      Some('.') => { tokens.push(Dot); cur = advance(cur) }
      Some(',') => { tokens.push(Comma); cur = advance(cur) }
      Some(';') => { tokens.push(Semicolon); cur = advance(cur) }
      Some('=') => { tokens.push(Equals); cur = advance(cur) }
      Some('<') => { tokens.push(LAngle); cur = advance(cur) }
      Some('>') => { tokens.push(RAngle); cur = advance(cur) }
      Some('[') => {
        let (content, after) = read_domain_literal(cur)
        tokens.push(DomainLiteral(content))
        cur = after
      }
      Some(']') => { tokens.push(RBracket); cur = advance(cur) }
      Some('(') => { tokens.push(LParen); cur = advance(cur) }
      Some(')') => { tokens.push(RParen); cur = advance(cur) }
      Some('/') => { tokens.push(Slash); cur = advance(cur) }

      // Quoted string
      Some('"') => {
        let (qs, after) = read_quoted_string(cur)
        tokens.push(QuotedString(qs))
        cur = after
      }

      // Any other character: treat as atom
      Some(c) if is_atext(c) => {
        let (atom, after) = read_atom(cur)
        tokens.push(Atom(atom))
        cur = after
      }

      // Skip unknown characters
      Some(_) => {
        cur = advance(cur)
      }
    }
  }

  tokens.push(EOF)
  tokens
}
