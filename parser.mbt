/// TOML parser: converts tokens into a TomlValue::Table document.

struct Parser {
  tokens : Array[Token]
  pos : Int
}

fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, pos: 0 }
}

fn peek_token(p : Parser) -> Token {
  p.tokens[p.pos]
}

fn next(p : Parser) -> Parser {
  { tokens: p.tokens, pos: p.pos + 1 }
}

/// Parse a full TOML document. Returns a Table.
pub fn parse_document(input : String) -> TomlValue {
  let tokens = tokenize(input)
  let p = Parser::new(tokens)
  let (root, _) = parse_toplevel(p)
  root
}

fn parse_toplevel(p : Parser) -> (TomlValue, Parser) {
  let mut cur = p
  let mut root = Table([])
  let mut table_path : Array[String] = []

  while true {
    let token = peek_token(cur)
    match token {
      EOF => break
      Newline => {
        cur = next(cur)
        continue
      }
      LBracket | DoubleLBracket => {
        let (new_path, after) = parse_table_header(cur)
        table_path = new_path
        cur = after
        continue
      }
      _ => {
        let (keys, value, after) = parse_keyval(cur)
        cur = after
        let mut full_keys : Array[String] = []
        let mut pi = 0
        while pi < table_path.length() {
          full_keys.push(table_path[pi])
          pi = pi + 1
        }
        let mut ki = 0
        while ki < keys.length() {
          full_keys.push(keys[ki])
          ki = ki + 1
        }
        root = set_dotted_keys(root, full_keys, value)
        continue
      }
    }
  }
  (root, cur)
}

/// Set a value using dotted keys: a.b.c creates nested tables.
fn set_dotted_keys(
  root : TomlValue,
  keys : Array[String],
  value : TomlValue,
) -> TomlValue {
  let mut r = root
  let mut i = 0
  while i < keys.length() - 1 {
    let k = keys[i]
    let existing = table_get(r, k)
    let next = match existing {
      None => Table([])
      Some(v) => v
    }
    let next_table = match next {
      Table(_) => next
      _ => Table([])
    }
    r = table_set(r, k, next_table)
    r = next_table
    i = i + 1
  }
  let last_key = keys[keys.length() - 1]
  table_set(r, last_key, value)
}

/// Parse a table header: [table.name] or [[array.name]]
fn parse_table_header(p : Parser) -> (Array[String], Parser) {
  let token = peek_token(p)
  let mut cur = p
  let is_array = match token {
    DoubleLBracket => true
    _ => false
  }
  cur = next(cur)

  let keys : Array[String] = []
  while true {
    let t = peek_token(cur)
    match t {
      Key(s) => {
        keys.push(s)
        cur = next(cur)
      }
      Dot => {
        cur = next(cur)
        continue
      }
      RBracket | DoubleRBracket => {
        cur = next(cur)
        break
      }
      _ => break
    }
  }

  if is_array {
    match peek_token(cur) {
      DoubleRBracket => cur = next(cur)
      _ => ()
    }
  }

  match peek_token(cur) {
    Newline => cur = next(cur)
    _ => ()
  }

  (keys, cur)
}

/// Parse a key = value line.
fn parse_keyval(p : Parser) -> (Array[String], TomlValue, Parser) {
  let (keys, after_keys) = parse_key(p)
  let mut cur = after_keys

  match peek_token(cur) {
    Equals => cur = next(cur)
    _ => return (keys, Str(""), cur)
  }

  let (value, after_value) = parse_value(cur)
  cur = after_value

  match peek_token(cur) {
    Newline => cur = next(cur)
    _ => ()
  }

  (keys, value, cur)
}

/// Parse a key (bare or dotted: a.b.c)
fn parse_key(p : Parser) -> (Array[String], Parser) {
  let keys : Array[String] = []
  let mut cur = p

  while true {
    let token = peek_token(cur)
    match token {
      Key(s) => {
        keys.push(s)
        cur = next(cur)
      }
      String_(s) => {
        keys.push(s)
        cur = next(cur)
      }
      _ => break
    }
    match peek_token(cur) {
      Dot => cur = next(cur)
      _ => break
    }
  }

  (keys, cur)
}

/// Parse a TOML value.
fn parse_value(p : Parser) -> (TomlValue, Parser) {
  let token = peek_token(p)
  match token {
    String_(s) => {
      let cur = next(p)
      (Str(s), cur)
    }
    Integer(i) => {
      let cur = next(p)
      (Integer(i), cur)
    }
    Float(f) => {
      let cur = next(p)
      (Float(f), cur)
    }
    Bool(b) => {
      let cur = next(p)
      (Bool(b), cur)
    }
    LBracket => parse_array(p)
    LBrace => parse_inline_table(p)
    _ => {
      let cur = next(p)
      (Str(""), cur)
    }
  }
}

/// Parse an array: [val1, val2, ...]
fn parse_array(p : Parser) -> (TomlValue, Parser) {
  let mut cur = next(p) // skip [
  let values : Array[TomlValue] = []

  while true {
    match peek_token(cur) {
      RBracket => {
        cur = next(cur)
        break
      }
      Newline => {
        cur = next(cur)
        continue
      }
      Comma => {
        cur = next(cur)
        continue
      }
      EOF => break
      _ => {
        let (val, after) = parse_value(cur)
        values.push(val)
        cur = after
      }
    }
  }

  (Array(values), cur)
}

/// Parse an inline table: {key = value, ...}
fn parse_inline_table(p : Parser) -> (TomlValue, Parser) {
  let mut cur = next(p) // skip {
  let entries : Array[(String, TomlValue)] = []

  while true {
    match peek_token(cur) {
      RBrace => {
        cur = next(cur)
        break
      }
      Newline | Comma => {
        cur = next(cur)
        continue
      }
      EOF => break
      _ => {
        // Parse key
        let (keys, after_key) = parse_key(cur)
        cur = after_key
        // Expect =
        match peek_token(cur) {
          Equals => cur = next(cur)
          _ => break
        }
        // Parse value
        let (val, after_val) = parse_value(cur)
        cur = after_val
        // For inline tables, only use the last key segment
        let key = if keys.length() > 0 {
          keys[keys.length() - 1]
        } else {
          ""
        }
        entries.push((key, val))
      }
    }
  }

  (Table(entries), cur)
}
