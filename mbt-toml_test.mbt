// Blackbox tests for mbt-toml.
// Run with: moon test

///| Simple string value
test "parse_string" {
  let doc = @houjie/mbt-toml.parse("name = \"hello\"\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_eq(output, "name = \"hello\"\n")
}

///| Integer value
test "parse_integer" {
  let doc = @houjie/mbt-toml.parse("port = 8080\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_eq(output, "port = 8080\n")
}

///| Float value
test "parse_float" {
  let doc = @houjie/mbt-toml.parse("pi = 3.14\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_true(output.length() > 0)
}

///| Boolean true
test "parse_bool_true" {
  let doc = @houjie/mbt-toml.parse("enabled = true\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_eq(output, "enabled = true\n")
}

///| Boolean false
test "parse_bool_false" {
  let doc = @houjie/mbt-toml.parse("debug = false\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_eq(output, "debug = false\n")
}

///| Table header
test "parse_table" {
  let doc = @houjie/mbt-toml.parse("[server]\nhost = \"localhost\"\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_eq(output, "[server]\nhost = \"localhost\"\n")
}

///| Dotted key
test "parse_dotted_key" {
  let doc = @houjie/mbt-toml.parse("database.host = \"db.example.com\"\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_eq(output, "[database]\nhost = \"db.example.com\"\n")
}

///| Array of integers
test "parse_array" {
  let doc = @houjie/mbt-toml.parse("ports = [8080, 8081, 8082]\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_true(output.length() > 0)
}

///| Inline table
test "parse_inline_table" {
  let doc = @houjie/mbt-toml.parse("point = {x = 1, y = 2}\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_true(output.length() > 0)
}

///| Comment handling
test "parse_with_comments" {
  let doc = @houjie/mbt-toml.parse("# This is a comment\nname = \"test\"\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_eq(output, "name = \"test\"\n")
}

///| Multiple key-value pairs
test "parse_multiple_kv" {
  let input = "name = \"app\"\nversion = 1\n"
  let doc = @houjie/mbt-toml.parse(input)
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_eq(output, input)
}

///| Nested table
test "parse_nested_table" {
  let doc = @houjie/mbt-toml.parse("[a.b]\nkey = 42\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_true(output.length() > 0)
}

///| Hex integer
test "parse_hex_integer" {
  let doc = @houjie/mbt-toml.parse("color = 0xFF\n")
  let output = @houjie/mbt-toml.to_toml(doc)
  assert_eq(output, "color = 255\n")
}
