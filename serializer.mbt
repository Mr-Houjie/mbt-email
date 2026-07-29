/// TOML serializer: converts TomlValue AST back to TOML text.

/// Escape a string for TOML basic string output.
fn escape_toml_string(s : String) -> String {
  let sb = StringBuilder::new()
  let len = s.length()
  let mut i = 0
  while i < len {
    let c = s.unsafe_char_at(i)
    match c {
      '\\' => sb.write_string("\\\\")
      '"' => sb.write_string("\\\"")
      '\b' => sb.write_string("\\b")
      '\t' => sb.write_string("\\t")
      '\n' => sb.write_string("\\n")
      '\f' => sb.write_string("\\f")
      '\r' => sb.write_string("\\r")
      _ => sb.write_string(String::make(1, c))
    }
    i = i + 1
  }
  sb.to_string()
}

/// Serialize a TomlValue to TOML format string.
pub fn serialize(value : TomlValue) -> String {
  let sb = StringBuilder::new()
  serialize_table(value, sb, 0, "")
  sb.to_string()
}

/// Serialize a TOML table with optional prefix.
fn serialize_table(
  value : TomlValue,
  sb : StringBuilder,
  indent : Int,
  prefix : String,
) -> Unit {
  match value {
    Table(entries) => {
      let mut i = 0
      while i < entries.length() {
        let (key, val) = entries[i]
        serialize_keyval(key, val, sb, indent, prefix)
        i = i + 1
      }
    }
    _ => ()
  }
}

/// Serialize a single key-value pair.
fn serialize_keyval(
  key : String,
  value : TomlValue,
  sb : StringBuilder,
  indent : Int,
  prefix : String,
) -> Unit {
  match value {
    Table(entries) => {
      // Nested table: write as [prefix.key] header
      let full_key = if prefix.length() > 0 {
        prefix + "." + key
      } else {
        key
      }
      sb.write_string("[")
      sb.write_string(full_key)
      sb.write_string("]\n")
      serialize_table(value, sb, indent + 1, full_key)
    }
    Array(_) => {
      let full_key = if prefix.length() > 0 {
        prefix + "." + key
      } else {
        key
      }
      sb.write_string(quote_key(full_key))
      sb.write_string(" = ")
      serialize_value(value, sb, indent)
      sb.write_string("\n")
    }
    _ => {
      if prefix.length() > 0 {
        // Sub-key in a table
        sb.write_string(quote_key(key))
        sb.write_string(" = ")
        serialize_value(value, sb, indent)
        sb.write_string("\n")
      } else {
        sb.write_string(quote_key(key))
        sb.write_string(" = ")
        serialize_value(value, sb, indent)
        sb.write_string("\n")
      }
    }
  }
}

/// Quote a key if it contains special characters.
fn quote_key(key : String) -> String {
  let len = key.length()
  let mut needs_quote = false
  let mut i = 0
  while i < len {
    let c = key.unsafe_char_at(i)
    if !((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
         (c >= '0' && c <= '9') || c == '_' || c == '-') {
      needs_quote = true
      break
    }
    i = i + 1
  }
  if needs_quote {
    "\"" + key + "\""
  } else {
    key
  }
}

/// Serialize a TOML value to its text representation.
fn serialize_value(
  value : TomlValue,
  sb : StringBuilder,
  indent : Int,
) -> Unit {
  match value {
    Str(s) => {
      sb.write_string("\"")
      sb.write_string(escape_toml_string(s))
      sb.write_string("\"")
    }
    Integer(i) => sb.write_string(i.to_string())
    Float(f) => sb.write_string(f.to_string())
    Bool(b) => {
      if b {
        sb.write_string("true")
      } else {
        sb.write_string("false")
      }
    }
    Array(items) => {
      sb.write_string("[")
      let mut i = 0
      while i < items.length() {
        if i > 0 {
          sb.write_string(", ")
        }
        serialize_value(items[i], sb, indent)
        i = i + 1
      }
      sb.write_string("]")
    }
    Table(_) => {
      sb.write_string("{")
      // Inline table serialization
      let entries = match value {
        Table(e) => e
        _ => []
      }
      let mut i = 0
      while i < entries.length() {
        if i > 0 {
          sb.write_string(", ")
        }
        let (k, v) = entries[i]
        sb.write_string(quote_key(k))
        sb.write_string(" = ")
        serialize_value(v, sb, indent)
        i = i + 1
      }
      sb.write_string("}")
    }
  }
}
