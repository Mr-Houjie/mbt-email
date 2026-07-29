/// mbt-toml - TOML parser and serializer demonstration.
fn main {
  let input = StringBuilder::new()
  input.write_string("# mbt-toml demo configuration\n")
  input.write_string("name = \"mbt-toml\"\n")
  input.write_string("version = \"0.1.0\"\n")
  input.write_string("license = \"MIT\"\n\n")
  input.write_string("[author]\n")
  input.write_string("name = \"Mr-Houjie\"\n")
  input.write_string("email = \"dev@example.com\"\n\n")
  input.write_string("[dependencies]\n")
  input.write_string("moonbit = \">= 0.1.0\"\n\n")
  input.write_string("[[contributors]]\n")
  input.write_string("name = \"Contributor A\"\n")
  input.write_string("role = \"reviewer\"\n\n")
  input.write_string("tags = [\"toml\", \"parser\", \"config\"]\n")
  input.write_string("active = true\n")
  let toml_str = input.to_string()

  println("=== Input TOML ===")
  println(toml_str)

  let doc = @lib.parse(toml_str)

  println("=== Serialized TOML ===")
  let output = @lib.to_toml(doc)
  println(output)
}
