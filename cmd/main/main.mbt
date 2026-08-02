///|
/// CLI demo for mbt-email: parse and display email messages.
fn main {
  // Use a simple demo email when no arguments are provided
  let input = "From: alice@example.com\r\nTo: bob@example.com\r\nSubject: Hello\r\n\r\nHello, world!\r\n"

  // Parse the email
  let msg = @lib.parse(input)

  // Display headers
  println("=== Headers ===")
  for h in msg.headers {
    println(h.name + ": " + h.value)
  }

  // Display parsed addresses
  let from_val = @lib.get_header(msg, "From")
  match from_val {
    Some(v) => {
      let addrs = @lib.parse_address_list(v)
      if addrs.length() > 0 {
        println("")
        println("=== Parsed From Addresses ===")
        for a in addrs {
          println(
            @lib.address_to_string(a) +
            " (local=" +
            a.local_part +
            ", domain=" +
            a.domain +
            ")",
          )
        }
      }
    }
    None => ()
  }

  let to_val = @lib.get_header(msg, "To")
  match to_val {
    Some(v) => {
      let addrs = @lib.parse_address_list(v)
      if addrs.length() > 0 {
        println("")
        println("=== Parsed To Addresses ===")
        for a in addrs {
          println(@lib.address_to_string(a))
        }
      }
    }
    None => ()
  }

  // Display body
  match msg.body {
    Some(b) => {
      println("")
      println("=== Body ===")
      println(b)
    }
    None => ()
  }

  // Display MIME info if present
  match msg.mime_part {
    Some(_) => {
      println("")
      println("=== MIME Structure Detected ===")
    }
    None => ()
  }

  // Round-trip test
  println("")
  println("=== Round-trip Output ===")
  let output = @lib.to_string(msg)
  println(output)
}
