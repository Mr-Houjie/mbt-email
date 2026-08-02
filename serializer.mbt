/// Email/MIME serializer: converts Message AST back to RFC 5322 text.

///|
/// Serialize a Message to RFC 5322 format text.
pub fn message_to_string(msg : Message) -> String {
  let sb = StringBuilder::new()

  // Write headers
  for header in msg.headers {
    sb.write_string(header.name)
    sb.write_string(": ")
    sb.write_string(header.value)
    sb.write_string("\r\n")
  }

  // Empty line separating headers from body
  sb.write_string("\r\n")

  // Write body or MIME part
  match msg.mime_part {
    Some(part) => serialize_mime_part(part, sb)
    None =>
      match msg.body {
        Some(b) => {
          sb.write_string(b)
          // Ensure trailing newline
          if !b.has_suffix("\n") {
            sb.write_string("\r\n")
          }
        }
        None => ()
      }
  }

  sb.to_string()
}

///|
/// Serialize a MIME part to text.
fn serialize_mime_part(part : MimePart, sb : StringBuilder) -> Unit {
  match part.body {
    Body::Text(text) => {
      // Write part headers
      for h in part.headers {
        sb.write_string(h.name)
        sb.write_string(": ")
        sb.write_string(h.value)
        sb.write_string("\r\n")
      }
      sb.write_string("\r\n")
      sb.write_string(text)
      if !text.has_suffix("\n") {
        sb.write_string("\r\n")
      }
    }
    Body::Binary(bytes) => {
      for h in part.headers {
        sb.write_string(h.name)
        sb.write_string(": ")
        sb.write_string(h.value)
        sb.write_string("\r\n")
      }
      sb.write_string("\r\n")
      // Write base64-encoded binary content
      let encoded = base64_encode(bytes)
      sb.write_string(encoded)
      sb.write_string("\r\n")
    }
    Body::Multipart(parts) => {
      // Find the boundary from Content-Type header
      let boundary = find_boundary(part.headers)
      let bd = match boundary {
        Some(b) => b
        None => "----=_moonbit_boundary_"
      }

      match boundary {
        Some(_) => () // Content-Type already written in message headers
        None => {
          // Write Content-Type with boundary
          sb.write_string("Content-Type: multipart/mixed; boundary=\"")
          sb.write_string(bd)
          sb.write_string("\"\r\n")
          sb.write_string("\r\n")
        }
      }

      // Write each part
      for p in parts {
        sb.write_string("--")
        sb.write_string(bd)
        sb.write_string("\r\n")
        serialize_mime_part(p, sb)
      }

      // Closing boundary
      sb.write_string("--")
      sb.write_string(bd)
      sb.write_string("--\r\n")
    }
  }
}

///|
/// Find the boundary parameter from MIME headers.
fn find_boundary(headers : Array[Header]) -> String? {
  for h in headers {
    if h.name.to_lower() == "content-type" {
      let ct = parse_content_type(h.value)
      match ct {
        Some(c) => {
          for i = 0; i < c.params.length(); i = i + 1 {
            let (k, v) = c.params[i]
            if k == "boundary" {
              return Some(v)
            }
          }
          return None
        }
        None => ()
      }
    }
  }
  None
}

///|
/// Simple base64 encoder for Bytes.
fn base64_encode(data : Bytes) -> String {
  let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let result = StringBuilder::new()
  let len = data.length()
  let mut i = 0
  while i < len {
    let b1 = data[i].to_int() & 0xFF
    let b2 = if i + 1 < len { data[i + 1].to_int() & 0xFF } else { 0 }
    let b3 = if i + 2 < len { data[i + 2].to_int() & 0xFF } else { 0 }

    let c1 = (b1 >> 2) & 0x3F
    let c2 = ((b1 << 4) | (b2 >> 4)) & 0x3F
    let c3 = if i + 1 < len { ((b2 << 2) | (b3 >> 6)) & 0x3F } else { 64 }
    let c4 = if i + 2 < len { b3 & 0x3F } else { 64 }

    result.write_char(table.get_char(c1).unwrap())
    result.write_char(table.get_char(c2).unwrap())
    result.write_char(
      if i + 1 < len {
        table.get_char(c3).unwrap()
      } else {
        '='
      },
    )
    result.write_char(
      if i + 2 < len {
        table.get_char(c4).unwrap()
      } else {
        '='
      },
    )

    i = i + 3
  }
  result.to_string()
}

///|
/// Serialize an EmailAddress to string.
pub fn address_to_string(addr : EmailAddress) -> String {
  let local_part = addr.local_part
  // Check if local part needs quoting
  let needs_quote = local_part.contains("@") ||
    local_part.contains(" ") ||
    local_part.contains("<") ||
    local_part.contains(">") ||
    local_part.contains(",") ||
    local_part.contains(";") ||
    local_part.contains(":") ||
    local_part.contains("\\") ||
    local_part.contains("\"") ||
    local_part.contains("(") ||
    local_part.contains(")") ||
    local_part.contains("[") ||
    local_part.contains("]")

  let local_str = if needs_quote {
    "\"" + local_part + "\""
  } else {
    local_part
  }

  local_str + "@" + addr.domain
}
