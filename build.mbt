/// Message construction and enhanced serialization.
///
/// Provides helpers for building well-formed RFC 5322 messages and
/// serializing headers with proper folding and encoded-words.

/// Build a Message from header name/value pairs and a body.
pub fn build_message(headers : Array[(String, String)], body : String) -> Message {
  let hs : Array[Header] = []
  for hi = 0; hi < headers.length(); hi = hi + 1 {
    let (name, value) = headers[hi]
    hs.push(Header::{ name, value })
  }
  let clean_body = body.trim(chars="\r\n").to_owned()
  Message::{
    headers: hs,
    body: if clean_body.length() > 0 { Some(clean_body) } else { None },
    mime_part: None,
  }
}

/// Build a plain-text message from common fields.
pub fn make_text_message(
  from~ : String,
  to~ : String,
  subject~ : String,
  body~ : String,
  cc~ : String = "",
) -> Message {
  let headers : Array[(String, String)] = [
    ("From", from),
    ("To", to),
  ]
  if cc.length() > 0 {
    headers.push(("Cc", cc))
  }
  headers.push(("Subject", subject))
  headers.push(("MIME-Version", "1.0"))
  headers.push(("Content-Type", "text/plain; charset=utf-8"))
  headers.push(("Content-Transfer-Encoding", "7bit"))
  build_message(headers, body)
}

/// Build an HTML message with a text/plain alternative part.
pub fn make_html_message(
  from~ : String,
  to~ : String,
  subject~ : String,
  text_body~ : String,
  html_body~ : String,
) -> Message {
  let boundary = "----=_mbt_alt_01"
  let text_part =
    "Content-Type: text/plain; charset=utf-8\r\n" +
    "Content-Transfer-Encoding: 7bit\r\n" +
    "\r\n" +
    text_body + "\r\n"
  let html_part =
    "Content-Type: text/html; charset=utf-8\r\n" +
    "Content-Transfer-Encoding: 7bit\r\n" +
    "\r\n" +
    html_body + "\r\n"
  let body =
    "--" + boundary + "\r\n" +
    text_part +
    "--" + boundary + "\r\n" +
    html_part +
    "--" + boundary + "--\r\n"

  let headers : Array[(String, String)] = [
    ("From", from),
    ("To", to),
    ("Subject", subject),
    ("MIME-Version", "1.0"),
    ("Content-Type", "multipart/alternative; boundary=\"" + boundary + "\""),
  ]
  build_message(headers, body)
}

/// Fold a header value at 78 columns using RFC 5322 folding rules.
/// Continuation lines start with a single space.
pub fn fold_header_value(name : String, value : String) -> String {
  let first_line = name + ": " + value
  if first_line.length() <= 78 {
    return first_line
  }
  let sb = StringBuilder::new()
  let mut col = 0
  let mut i = 0
  let len = value.length()
  while i < len {
    let c = value.get_char(i).unwrap()
    if col >= 76 {
      sb.write_string("\r\n ")
      col = 0
    }
    sb.write_char(c)
    col = col + 1
    i = i + 1
  }
  name + ": " + sb.to_string()
}

/// Serialize a header block (all headers + blank line).
pub fn serialize_header_block(headers : Array[Header]) -> String {
  let sb = StringBuilder::new()
  for h in headers {
    let line = fold_header_value(h.name, h.value)
    sb.write_string(line)
    sb.write_string("\r\n")
  }
  sb.write_string("\r\n")
  sb.to_string()
}

/// Encode a header value for output: non-ASCII text becomes an
/// RFC 2047 encoded-word. ASCII-only values pass through unchanged.
pub fn encode_header_for_output(value : String) -> String {
  if is_ascii_only(value) {
    value
  } else {
    encode_encoded_word_b(value)
  }
}

/// Serialize a list of mailboxes into a header value string.
pub fn serialize_mailboxes(mbs : Array[Mailbox]) -> String {
  mailbox_list_to_string(mbs)
}

/// Render a plain-text message (without MIME) to a string.
pub fn render_text_message(msg : Message) -> String {
  message_to_string(msg)
}

/// Render a message with folded headers.
pub fn render_folded_message(msg : Message) -> String {
  let sb = StringBuilder::new()
  for h in msg.headers {
    let line = fold_header_value(h.name, h.value)
    sb.write_string(line)
    sb.write_string("\r\n")
  }
  sb.write_string("\r\n")
  match msg.body {
    Some(b) => {
      sb.write_string(b)
      if !b.has_suffix("\n") {
        sb.write_string("\r\n")
      }
    }
    None => ()
  }
  match msg.mime_part {
    Some(_) => ()
    None => ()
  }
  sb.to_string()
}

/// Render a MIME part tree with proper boundaries and content encodings.
pub fn render_mime_tree(part : MimePart) -> String {
  let sb = StringBuilder::new()
  render_mime_part_tree(part, sb)
  sb.to_string()
}

/// Recursively render a MIME part tree.
fn render_mime_part_tree(part : MimePart, sb : StringBuilder) -> Unit {
  // Write the part headers
  for h in part.headers {
    let line = fold_header_value(h.name, h.value)
    sb.write_string(line)
    sb.write_string("\r\n")
  }
  sb.write_string("\r\n")

  match part.body {
    Body::Text(text) => {
      sb.write_string(text)
      if !text.has_suffix("\n") {
        sb.write_string("\r\n")
      }
    }
    Body::Binary(bytes) => {
      // Base64-encode with line wrapping via the codec module
      let ints : Array[Int] = []
      for i = 0; i < bytes.length(); i = i + 1 {
        ints.push(bytes[i].to_int())
      }
      let encoded = b64_encode_bytes(ints)
      sb.write_string(encoded)
      if !encoded.has_suffix("\n") {
        sb.write_string("\r\n")
      }
    }
    Body::Multipart(parts) => {
      let boundary = match find_boundary(part.headers) {
        Some(b) => b
        None => "----=_mbt_boundary_"
      }
      for p in parts {
        sb.write_string("--")
        sb.write_string(boundary)
        sb.write_string("\r\n")
        render_mime_part_tree(p, sb)
      }
      sb.write_string("--")
      sb.write_string(boundary)
      sb.write_string("--\r\n")
    }
  }
}

/// Create a multipart/mixed message from text and attachment parts.
pub fn make_multipart_message(
  from~ : String,
  to~ : String,
  subject~ : String,
  parts~ : Array[MimePart],
) -> Message {
  let boundary = "----=_mbt_mixed_01"
  let body = StringBuilder::new()
  for p in parts {
    body.write_string("--")
    body.write_string(boundary)
    body.write_string("\r\n")
    body.write_string(render_mime_tree(p))
  }
  body.write_string("--")
  body.write_string(boundary)
  body.write_string("--\r\n")

  let headers : Array[(String, String)] = [
    ("From", from),
    ("To", to),
    ("Subject", subject),
    ("MIME-Version", "1.0"),
    ("Content-Type", "multipart/mixed; boundary=\"" + boundary + "\""),
  ]
  build_message(headers, body.to_string())
}

/// Serialize headers with RFC 2047 encoding applied to values.
pub fn serialize_encoded_headers(headers : Array[Header]) -> String {
  let sb = StringBuilder::new()
  for h in headers {
    let encoded = encode_header_for_output(h.value)
    let line = fold_header_value(h.name, encoded)
    sb.write_string(line)
    sb.write_string("\r\n")
  }
  sb.write_string("\r\n")
  sb.to_string()
}

/// Convert a ContentType into a header value string.
pub fn content_type_to_string(ct : ContentType) -> String {
  let sb = StringBuilder::new()
  sb.write_string(ct.media_type)
  sb.write_string("/")
  sb.write_string(ct.sub_type)
  for pi = 0; pi < ct.params.length(); pi = pi + 1 {
    let (k, v) = ct.params[pi]
    sb.write_string("; ")
    sb.write_string(k)
    sb.write_string("=")
    // Quote values containing special characters
    let needs_quote = v.contains(";") || v.contains("\"") || v.contains(" ") ||
                      v.contains("(") || v.contains(")")
    if needs_quote {
      sb.write_string("\"")
      sb.write_string(v)
      sb.write_string("\"")
    } else {
      sb.write_string(v)
    }
  }
  sb.to_string()
}

/// Convert a ContentDisposition into a header value string.
pub fn disposition_to_string(cd : ContentDisposition) -> String {
  let sb = StringBuilder::new()
  sb.write_string(cd.disposition)
  for pi = 0; pi < cd.params.length(); pi = pi + 1 {
    let (k, v) = cd.params[pi]
    sb.write_string("; ")
    sb.write_string(k)
    sb.write_string("=")
    sb.write_string("\"")
    sb.write_string(v)
    sb.write_string("\"")
  }
  sb.to_string()
}

/// Generate a random boundary string from a seed.
pub fn generate_boundary(seed~ : Int = 0) -> String {
  "----=_mbt_part_" + seed.to_string() + "_" + (seed * 48271 % 1000000000).to_string()
}
