/// mbt-toml: A TOML v1.0 configuration parser and serializer for MoonBit.
///
/// This package provides a complete TOML pipeline:
///   parse() - Parse TOML text into TomlValue AST
///   serialize() - Convert TomlValue back to TOML text
///
/// Supported features:
///   - Key-value pairs (bare and quoted keys)
///   - Dotted keys (a.b.c = value)
///   - Tables ([table] and [[array-of-tables]])
///   - Inline tables ({key = value})
///   - Arrays ([1, 2, 3])
///   - String types (basic, literal, multi-line)
///   - Number types (integer decimal/hex/oct/bin, float)
///   - Booleans (true/false)
///   - Comments (# comment)

/// Parse a TOML string into a TomlValue AST.
/// The root value is always a Table.
///
/// Example:
/// ```
/// let config = parse("name = \"app\"\n[server]\nport = 8080\n")
/// let name = table_get(config, "name")
/// ```
pub fn parse(input : String) -> TomlValue {
  parse_document(input)
}

/// Serialize a TomlValue to TOML format text.
pub fn to_toml(value : TomlValue) -> String {
  serialize(value)
}
