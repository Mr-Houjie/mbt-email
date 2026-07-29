/// TOML AST node types.
/// Represents values in a TOML document.

/// A TOML value.
pub enum TomlValue {
  /// TOML string (basic, literal, multi-line)
  Str(String)
  /// TOML integer (decimal, hex, octal, binary)
  Integer(Int)
  /// TOML float (regular, inf, nan)
  Float(Double)
  /// TOML boolean
  Bool(Bool)
  /// TOML array (heterogeneous values)
  Array(Array[TomlValue])
  /// TOML table (ordered key-value pairs)
  Table(Array[(String, TomlValue)])
}

/// Look up a key in a TomlValue::Table.
/// Returns None if the value is not a Table or key not found.
pub fn table_get(table : TomlValue, key : String) -> TomlValue? {
  match table {
    Table(entries) => {
      let mut i = 0
      while i < entries.length() {
        let (k, v) = entries[i]
        if k == key {
          return Some(v)
        }
        i = i + 1
      }
      None
    }
    _ => None
  }
}

/// Set a key in a table. Creates the table if needed.
pub fn table_set(
  table : TomlValue,
  key : String,
  value : TomlValue,
) -> TomlValue {
  match table {
    Table(entries) => {
      let mut found = false
      let mut i = 0
      while i < entries.length() {
        let (k, _) = entries[i]
        if k == key {
          entries[i] = (key, value)
          found = true
          break
        }
        i = i + 1
      }
      if !found {
        entries.push((key, value))
      }
      Table(entries)
    }
    _ => Table([(key, value)])
  }
}
