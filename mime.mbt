/// MIME message parser: handles multipart message structure.
///
/// Implements RFC 2045/2046 MIME message parsing including:
///   - Multipart boundary detection and splitting
///   - Recursive parsing of nested multipart bodies
///   - Per-part header extraction
///   - Attachment identification
///
/// The parser works on the raw text level, scanning line by line for
/// boundary delimiters. Each part's headers and body are captured and
/// converted into the shared AST types.

/// Parse a full MIME message from raw text.
/// Returns a Message with an optional MimePart tree.
pub fn parse_mime_message(input : String) -> Message {
  // First extract headers using the base message parser
  let base = parse_message(input)
  let headers = base.headers

  // Determine the Content-Type
  let ct_value = get_header_from_array(headers, "Content-Type")
  let mime_part = match ct_value {
    None => None
    Some(v) => {
      let ct = parse_content_type(v)
      match ct {
        None => None
        Some(parsed) => {
          if is_multipart(parsed) {
            // Find boundary parameter
            let boundary = content_type_param(parsed, "boundary")
            match boundary {
              None => None
              Some(b) => {
                let body = get_message_body(base)
                match body {
                  None => None
                  Some(body_text) => {
                    let sub_parts = split_multipart(body_text, b)
                    let parts : Array[MimePart] = []
                    for sub in sub_parts {
                      let part = parse_mime_part(sub)
                      parts.push(part)
                    }
                    Some(MimePart::{
                      headers: [],
                      body: Body::Multipart(parts),
                    })
                  }
                }
              }
            }
          } else {
            // Non-multipart: treat the body as a single part
            let body = get_message_body(base)
            match body {
              None => None
              Some(body_text) => {
                let part_headers : Array[Header] = []
                for h in headers {
                  if is_mime_header(h.name) {
                    part_headers.push(h)
                  }
                }
                // Decode body if base64 or quoted-printable
                let decoded = decode_body_if_needed(body_text, headers)
                Some(MimePart::{
                  headers: part_headers,
                  body: Body::Text(decoded),
                })
              }
            }
          }
        }
      }
    }
  }

  Message::{
    headers,
    body: base.body,
    mime_part,
  }
}

/// Get a header value from an array of headers (case-insensitive).
fn get_header_from_array(headers : Array[Header], name : String) -> String? {
  let lower = name.to_lower()
  for h in headers {
    if h.name.to_lower() == lower {
      return Some(h.value)
    }
  }
  None
}

/// Get the body text of a message, trimming a single trailing newline.
fn get_message_body(msg : Message) -> String? {
  match msg.body {
    None => None
    Some(b) => {
      let trimmed = b.trim(chars="\r\n").to_owned()
      if trimmed.length() > 0 {
        Some(trimmed)
      } else {
        None
      }
    }
  }
}

/// Check whether a header name is a MIME-specific header.
fn is_mime_header(name : String) -> Bool {
  let lower = name.to_lower()
  lower == "content-type" ||
  lower == "content-disposition" ||
  lower == "content-transfer-encoding" ||
  lower == "content-id" ||
  lower == "content-description" ||
  lower == "mime-version"
}

/// Decode a message body based on its Content-Transfer-Encoding header.
/// Supports base64 and quoted-printable; other encodings pass through.
fn decode_body_if_needed(body_text : String, headers : Array[Header]) -> String {
  let cte = get_header_from_array(headers, "Content-Transfer-Encoding")
  let lower = match cte {
    None => ""
    Some(v) => v.to_lower()
  }
  if lower.contains("base64") {
    // Remove whitespace and decode
    let compact = remove_whitespace(body_text)
    match base64_decode(compact) {
      Some(decoded) => decoded
      None => body_text
    }
  } else if lower.contains("quoted-printable") {
    match quoted_printable_decode(body_text) {
      Some(decoded) => decoded
      None => body_text
    }
  } else {
    body_text
  }
}

/// Remove all whitespace characters from a string.
fn remove_whitespace(input : String) -> String {
  let sb = StringBuilder::new()
  for c in input {
    if c != ' ' && c != '\t' && c != '\r' && c != '\n' {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

/// Decode a quoted-printable encoded string (RFC 2045 section 6.7).
fn quoted_printable_decode(input : String) -> String? {
  let sb = StringBuilder::new()
  let len = input.length()
  let mut i = 0
  while i < len {
    let c = input.get_char(i).unwrap()
    if c == '=' {
      if i + 1 < len && input.get_char(i + 1).unwrap() == '\n' {
        // Soft line break: skip both characters
        i = i + 2
        continue
      } else if i + 2 < len && input.get_char(i + 1).unwrap() == '\r' &&
                input.get_char(i + 2).unwrap() == '\n' {
        // Soft line break with CRLF: skip all three
        i = i + 3
        continue
      } else if i + 2 < len {
        // Hex escape: =XX
        let h1 = input.get_char(i + 1).unwrap()
        let h2 = input.get_char(i + 2).unwrap()
        let byte = hex_value(h1, h2)
        match byte {
          Some(b) => sb.write_char(Int::unsafe_to_char(b))
          None => {
            // Invalid escape, pass through
            sb.write_char('=')
            i = i + 1
            continue
          }
        }
        i = i + 3
        continue
      } else {
        sb.write_char(c)
        i = i + 1
        continue
      }
    }
    sb.write_char(c)
    i = i + 1
  }
  Some(sb.to_string())
}

/// Parse a two-char hex string to an integer value.
fn hex_value(h1 : Char, h2 : Char) -> Int? {
  let hi = hex_digit(h1)
  let lo = hex_digit(h2)
  match (hi, lo) {
    (Some(a), Some(b)) => Some(a * 16 + b)
    _ => None
  }
}

/// Convert a hex character to its numeric value.
fn hex_digit(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

/// Split a multipart body into raw sub-part strings using a boundary.
fn split_multipart(body : String, boundary : String) -> Array[String] {
  let results : Array[String] = []
  let opening = "--" + boundary
  let closing = opening + "--"

  // Split body into lines for boundary detection
  let lines = split_lines(body)
  let mut current : Array[String] = []
  let mut in_part = false

  for line in lines {
    let trimmed = line.trim(chars=" \t").to_owned()
    if trimmed == opening {
      // Start a new part
      if in_part {
        // Save previous part (drop its trailing blank separator)
        let part_text = join_lines(current)
        results.push(trim_part(part_text))
      }
      current = []
      in_part = true
      continue
    } else if trimmed == closing {
      // End of multipart
      if in_part {
        let part_text = join_lines(current)
        results.push(trim_part(part_text))
      }
      in_part = false
      break
    } else if trimmed.has_prefix("--") && in_part {
      // Nested or other boundary delimiter: treat as part boundary stop
      // Only stop if it is not a valid content line
      continue
    }

    if in_part {
      current.push(line)
    }
  }

  // If no closing boundary was found, flush remaining part
  if in_part {
    let part_text = join_lines(current)
    results.push(trim_part(part_text))
  }

  results
}

/// Split a string into lines (keeping line contents, without newlines).
fn split_lines(input : String) -> Array[String] {
  let results : Array[String] = []
  let mut start = 0
  let mut i = 0
  let len = input.length()
  while i < len {
    let c = input.get_char(i).unwrap()
    if c == '\n' {
      let line = input.unsafe_substring(start=start, end=i)
      // Strip trailing \r
      let clean = if line.has_suffix("\r") {
        line.unsafe_substring(start=0, end=line.length() - 1)
      } else {
        line
      }
      results.push(clean)
      start = i + 1
    }
    i = i + 1
  }
  if start < len {
    results.push(input.unsafe_substring(start=start, end=len))
  }
  results
}

/// Join an array of lines back into a string with newlines.
fn join_lines(lines : Array[String]) -> String {
  let sb = StringBuilder::new()
  let mut first = true
  for line in lines {
    if !first {
      sb.write_string("\n")
    }
    sb.write_string(line)
    first = false
  }
  sb.to_string()
}

/// Trim leading and trailing blank lines from a part body.
fn trim_part(input : String) -> String {
  let lines = split_lines(input)
  let mut start = 0
  let mut end = lines.length()
  while start < end && lines[start].trim(chars=" \t\r\n").to_owned().length() == 0 {
    start = start + 1
  }
  while end > start && lines[end - 1].trim(chars=" \t\r\n").to_owned().length() == 0 {
    end = end - 1
  }
  let trimmed : Array[String] = []
  let mut i = start
  while i < end {
    trimmed.push(lines[i])
    i = i + 1
  }
  join_lines(trimmed)
}

/// Parse a single MIME part from its raw text (headers + body).
fn parse_mime_part(raw : String) -> MimePart {
  let base = parse_message(raw)
  let headers = base.headers
  let body = get_message_body(base)

  // Decode the body based on Content-Transfer-Encoding
  let decoded = match body {
    None => ""
    Some(b) => decode_body_if_needed(b, headers)
  }

  // Check whether this part is itself multipart (nested)
  let ct_value = get_header_from_array(headers, "Content-Type")
  let nested = match ct_value {
    None => None
    Some(v) => {
      let ct = parse_content_type(v)
      match ct {
        None => None
        Some(parsed) if is_multipart(parsed) => {
          let boundary = content_type_param(parsed, "boundary")
          match boundary {
            None => None
            Some(b) => {
              let sub_parts = split_multipart(decoded, b)
              let parts : Array[MimePart] = []
              for sub in sub_parts {
                parts.push(parse_mime_part(sub))
              }
              Some(Body::Multipart(parts))
            }
          }
        }
        _ => None
      }
    }
  }

  let part_body = match nested {
    Some(b) => b
    None => Body::Text(decoded)
  }

  MimePart::{
    headers,
    body: part_body,
  }
}

/// Check whether a MIME part is an attachment (has attachment disposition).
pub fn is_attachment(part : MimePart) -> Bool {
  let cd = get_header_from_array(part.headers, "Content-Disposition")
  match cd {
    None => false
    Some(v) => {
      let parsed = parse_content_disposition(v)
      match parsed {
        None => false
        Some(d) => d.disposition == "attachment"
      }
    }
  }
}

/// Get the filename from a MIME part, if any.
pub fn part_filename(part : MimePart) -> String? {
  let cd = get_header_from_array(part.headers, "Content-Disposition")
  match cd {
    None => {
      // Try Content-Type name parameter
      let ct = get_header_from_array(part.headers, "Content-Type")
      match ct {
        None => None
        Some(v) => {
          let parsed = parse_content_type(v)
          match parsed {
            None => None
            Some(c) => content_type_param(c, "name")
          }
        }
      }
    }
    Some(v) => {
      let parsed = parse_content_disposition(v)
      match parsed {
        None => None
        Some(d) => disposition_param(d, "filename")
      }
    }
  }
}

/// Collect all attachments from a MIME part tree.
pub fn collect_attachments(part : MimePart) -> Array[MimePart] {
  let results : Array[MimePart] = []
  match part.body {
    Body::Multipart(parts) => {
      for p in parts {
        let sub = collect_attachments(p)
        for s in sub {
          results.push(s)
        }
      }
    }
    _ => {
      if is_attachment(part) {
        results.push(part)
      }
    }
  }
  results
}

/// Get the plain-text content from a MIME part tree, if any.
pub fn plain_text(part : MimePart) -> String? {
  match part.body {
    Body::Text(t) => Some(t)
    Body::Multipart(parts) => {
      for p in parts {
        let ct = get_header_from_array(p.headers, "Content-Type")
        match ct {
          None => {
            let t = plain_text(p)
            match t {
              Some(s) => return Some(s)
              None => ()
            }
          }
          Some(v) => {
            if v.to_lower().contains("text/plain") {
              let t = plain_text(p)
              match t {
                Some(s) => return Some(s)
                None => ()
              }
            } else {
              let t = plain_text(p)
              match t {
                Some(s) => return Some(s)
                None => ()
              }
            }
          }
        }
      }
      None
    }
    Body::Binary(_) => None
  }
}

/// Extract the text content of a MIME part as a string.
/// For text parts returns the decoded text; for binary parts returns None.
pub fn part_body_text(part : MimePart) -> String? {
  match part.body {
    Body::Text(t) => Some(t)
    Body::Binary(_) => None
    Body::Multipart(_) => None
  }
}
