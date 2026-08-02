/// Email/MIME parser: converts raw email text into Message AST.
///
/// Parses RFC 5322 message format using a simple line-by-line approach.
/// Handles headers, body, MIME content types, and email addresses.

///|
/// Parse a full email message from raw text.
/// Splits headers from body at the first blank line.
pub fn parse_message(input : String) -> Message {
  let headers : Array[Header] = []
  let mut body_start = 0
  let mut i = 0
  let len = input.length()

  // Parse headers line by line
  let mut in_fold = false
  let mut current_name = ""
  let mut current_value = StringBuilder::new()

  while i < len {
    let rest = input.unsafe_substring(start=i, end=len)

    // Check for CRLF or LF
    let nl_pos = match rest.find("\r\n") {
      Some(p) => p
      None =>
        match rest.find("\n") {
          Some(p) => p
          None => len - i // no newline, read to end
        }
    }

    let line = if nl_pos > 0 {
      rest.unsafe_substring(start=0, end=nl_pos)
    } else {
      ""
    }

    let nl_len = if i + nl_pos + 2 <= len &&
      rest.unsafe_substring(start=nl_pos, end=nl_pos + 2) == "\r\n" {
      2
    } else if i + nl_pos < len && rest.get_char(nl_pos).unwrap() == '\n' {
      1
    } else {
      0
    }

    // Check if line is empty (blank line = end of headers)
    let trimmed_line = line.trim(chars=" \t").to_owned()
    if trimmed_line.length() == 0 && !in_fold {
      // Empty line: end of headers
      i = i + nl_pos + nl_len
      body_start = i
      break
    }

    // Check for header continuation (folding): line starts with WSP
    if in_fold {
      // Append to current header value
      current_value.write_char(' ')
      current_value.write_string(trimmed_line)
      i = i + nl_pos + nl_len
      // Check if next line is also folded
      let next_pos = i
      if next_pos < len {
        let next_ch = input.get_char(next_pos).unwrap()
        in_fold = next_ch == ' ' || next_ch == '\t'
      } else {
        in_fold = false
      }
      if !in_fold {
        // End of folded header
        headers.push(Header::{
          name: current_name,
          value: current_value.to_string(),
        })
        current_name = ""
        current_value = StringBuilder::new()
      }
      continue
    }

    // Look for colon separator: header name ends at first ':'
    let colon_pos = line.find(":")
    match colon_pos {
      None => {
        // No colon, skip this line as malformed
        i = i + nl_pos + nl_len
        continue
      }
      Some(cp) => {
        let name = line
          .unsafe_substring(start=0, end=cp)
          .trim_end(chars=" \t")
          .to_owned()
        let value_start = cp + 1
        let value = if value_start < line.length() {
          line
          .unsafe_substring(start=value_start, end=line.length())
          .trim(chars=" \t")
          .to_owned()
        } else {
          ""
        }
        current_name = name
        current_value = StringBuilder::new()
        current_value.write_string(value)
        i = i + nl_pos + nl_len

        // Check if next line is folded
        let next_pos = i
        if next_pos < len {
          let next_ch = input.get_char(next_pos).unwrap()
          in_fold = next_ch == ' ' || next_ch == '\t'
        } else {
          in_fold = false
        }
        if !in_fold {
          headers.push(Header::{
            name: current_name,
            value: current_value.to_string(),
          })
          current_name = ""
          current_value = StringBuilder::new()
        }
      }
    }
  }

  // Store any pending header
  if current_name.length() > 0 {
    headers.push(Header::{
      name: current_name,
      value: current_value.to_string(),
    })
  }

  // Parse body
  let body = if body_start < len {
    let body_text = input.unsafe_substring(start=body_start, end=len)
    if body_text.trim(chars=" \t\r\n").to_owned().length() > 0 {
      Some(body_text)
    } else {
      None
    }
  } else {
    None
  }

  Message::{ headers, body, mime_part: None }
}

///|
/// Parse a single email address from a string.
/// Supports: user@domain, <user@domain>, "Name" <user@domain>
pub fn parse_address(input : String) -> EmailAddress? {
  let trimmed = input.trim(chars=" \t\r\n").to_owned()
  if trimmed.length() == 0 {
    return None
  }

  let addr_part = if trimmed.has_prefix("<") {
    let end = trimmed.find(">")
    match end {
      Some(pos) => trimmed.unsafe_substring(start=1, end=pos)
      None => return None
    }
  } else if trimmed.contains("<") && trimmed.has_suffix(">") {
    let start = trimmed.find("<")
    match start {
      Some(pos) =>
        trimmed.unsafe_substring(start=pos + 1, end=trimmed.length() - 1)
      None => return None
    }
  } else {
    trimmed
  }

  let at_pos = addr_part.find("@")
  match at_pos {
    None => None
    Some(pos) => {
      let lp = addr_part.unsafe_substring(start=0, end=pos)
      let domain = addr_part.unsafe_substring(
        start=pos + 1,
        end=addr_part.length(),
      )
      let clean_local = if lp.has_prefix("\"") && lp.has_suffix("\"") {
        lp.unsafe_substring(start=1, end=lp.length() - 1)
      } else {
        lp
      }
      if clean_local.length() > 0 && domain.length() > 0 {
        Some(EmailAddress::{ local_part: clean_local, domain })
      } else {
        None
      }
    }
  }
}

///|
/// Parse multiple email addresses from a header value.
pub fn parse_address_list(input : String) -> Array[EmailAddress] {
  let results : Array[EmailAddress] = []
  let trimmed = input.trim(chars=" \t\r\n").to_owned()
  if trimmed.length() == 0 {
    return results
  }

  let parts = split_addr_list(trimmed)
  for part in parts {
    let addr = parse_address(part)
    match addr {
      Some(a) => results.push(a)
      None => ()
    }
  }
  results
}

///|
/// Split address list by commas, respecting quotes and angle brackets.
fn split_addr_list(input : String) -> Array[String] {
  let results : Array[String] = []
  let mut start = 0
  let mut in_quote = false
  let mut in_angle = false
  let mut i = 0

  while i < input.length() {
    let c = input.get_char(i).unwrap()
    if c == '"' && !in_angle {
      in_quote = !in_quote
    } else if c == '<' && !in_quote {
      in_angle = true
    } else if c == '>' && !in_quote {
      in_angle = false
    } else if c == ',' && !in_quote && !in_angle {
      let part = input
        .unsafe_substring(start~, end=i)
        .trim(chars=" \t\r\n")
        .to_owned()
      if part.length() > 0 {
        results.push(part)
      }
      start = i + 1
    }
    i = i + 1
  }

  let last = input
    .unsafe_substring(start~, end=input.length())
    .trim(chars=" \t\r\n")
    .to_owned()
  if last.length() > 0 {
    results.push(last)
  }
  results
}

///|
/// Parse a MIME Content-Type header value.
pub fn parse_content_type(value : String) -> ContentType? {
  let trimmed = value.trim(chars=" \t").to_owned()
  if trimmed.length() == 0 {
    return None
  }

  let parts = split_semi(trimmed)
  if parts.length() == 0 {
    return None
  }

  let type_sub = parts[0]
  let slash_pos = type_sub.find("/")
  let (media_type, sub_type) = match slash_pos {
    None => (type_sub.to_lower(), "")
    Some(pos_slash) =>
      (
        type_sub.unsafe_substring(start=0, end=pos_slash).to_lower(),
        type_sub
        .unsafe_substring(start=pos_slash + 1, end=type_sub.length())
        .to_lower(),
      )
  }

  let params : Array[(String, String)] = []
  let mut pi = 1
  while pi < parts.length() {
    let param = parts[pi]
    let eq_pos = param.find("=")
    match eq_pos {
      None => ()
      Some(pos_eq) => {
        let key = param
          .unsafe_substring(start=0, end=pos_eq)
          .trim(chars=" \t")
          .to_lower()
          .to_owned()
        let val_raw = param
          .unsafe_substring(start=pos_eq + 1, end=param.length())
          .trim(chars=" \t")
          .to_owned()
        let val = if val_raw.has_prefix("\"") && val_raw.has_suffix("\"") {
          val_raw.unsafe_substring(start=1, end=val_raw.length() - 1)
        } else {
          val_raw
        }
        params.push((key, val))
      }
    }
    pi = pi + 1
  }

  Some(ContentType::{ media_type, sub_type, params })
}

///|
/// Parse a MIME Content-Disposition header value.
pub fn parse_content_disposition(value : String) -> ContentDisposition? {
  let trimmed = value.trim(chars=" \t").to_owned()
  if trimmed.length() == 0 {
    return None
  }

  let parts = split_semi(trimmed)
  if parts.length() == 0 {
    return None
  }

  let disposition = parts[0].to_lower()
  let params : Array[(String, String)] = []
  let mut pi = 1
  while pi < parts.length() {
    let param = parts[pi]
    let eq_pos = param.find("=")
    match eq_pos {
      None => ()
      Some(pos_eq) => {
        let key = param
          .unsafe_substring(start=0, end=pos_eq)
          .trim(chars=" \t")
          .to_lower()
          .to_owned()
        let val_raw = param
          .unsafe_substring(start=pos_eq + 1, end=param.length())
          .trim(chars=" \t")
          .to_owned()
        let val = if val_raw.has_prefix("\"") && val_raw.has_suffix("\"") {
          val_raw.unsafe_substring(start=1, end=val_raw.length() - 1)
        } else {
          val_raw
        }
        params.push((key, val))
      }
    }
    pi = pi + 1
  }

  Some(ContentDisposition::{ disposition, params })
}

///|
/// Split a string by semicolons, respecting quotes.
fn split_semi(input : String) -> Array[String] {
  let parts : Array[String] = []
  let mut start = 0
  let mut in_quote = false
  let mut i = 0
  while i < input.length() {
    let c = input.get_char(i).unwrap()
    if c == '"' {
      in_quote = !in_quote
    } else if c == ';' && !in_quote {
      let part = input
        .unsafe_substring(start~, end=i)
        .trim(chars=" \t")
        .to_owned()
      parts.push(part)
      start = i + 1
    }
    i = i + 1
  }
  let last = input
    .unsafe_substring(start~, end=input.length())
    .trim(chars=" \t")
    .to_owned()
  if last.length() > 0 {
    parts.push(last)
  }
  parts
}

///|
/// Decode an RFC 2047 encoded-word.
/// Format: =?charset?encoding?encoded_text?=
pub fn decode_encoded_word(input : String) -> String? {
  let s = input.trim(chars=" \t").to_owned()
  if !s.has_prefix("=?") || !s.has_suffix("?=") {
    return None
  }

  let inner = s.unsafe_substring(start=2, end=s.length() - 2)
  let q1 = inner.find("?")
  match q1 {
    None => None
    Some(p1) => {
      let after_charset = inner.unsafe_substring(
        start=p1 + 1,
        end=inner.length(),
      )
      let q2 = after_charset.find("?")
      match q2 {
        None => None
        Some(p2) => {
          let encoding = after_charset
            .unsafe_substring(start=0, end=p2)
            .to_upper()
          let encoded = after_charset.unsafe_substring(
            start=p2 + 1,
            end=after_charset.length(),
          )
          match encoding {
            "B" => decode_b64_word(encoded)
            "Q" => decode_q_word(encoded)
            _ => None
          }
        }
      }
    }
  }
}

///|
fn decode_b64_word(input : String) -> String? {
  let decoded = base64_decode(input)
  match decoded {
    Some(s) => Some(s)
    None => None
  }
}

///|
fn decode_q_word(input : String) -> String? {
  let result = StringBuilder::new()
  let len = input.length()
  let mut i = 0
  while i < len {
    let c = input.get_char(i).unwrap()
    if c == '_' {
      result.write_char(' ')
    } else if c == '=' {
      if i + 2 < len {
        let h1 = input.get_char(i + 1).unwrap()
        let h2 = input.get_char(i + 2).unwrap()
        let byte = hex_byte(h1, h2)
        match byte {
          Some(b) => result.write_char(Int::unsafe_to_char(b))
          None => ()
        }
        i = i + 2
      }
    } else {
      result.write_char(c)
    }
    i = i + 1
  }
  Some(result.to_string())
}

///|
fn hex_byte(h1 : Char, h2 : Char) -> Int? {
  fn hex_val(c : Char) -> Int? {
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
  match (hex_val(h1), hex_val(h2)) {
    (Some(hi), Some(lo)) => Some(hi * 16 + lo)
    _ => None
  }
}

///|
fn base64_decode(input : String) -> String? {
  let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let len = input.length()
  if len % 4 != 0 {
    return None
  }
  let result = StringBuilder::new()
  let mut i = 0
  while i < len {
    let c1 = input.get_char(i).unwrap()
    let c2 = input.get_char(i + 1).unwrap()
    let c3 = input.get_char(i + 2).unwrap()
    let c4 = input.get_char(i + 3).unwrap()

    let v1 = b64_index(table, c1)
    let v2 = b64_index(table, c2)
    let v3 = b64_index(table, c3)
    let v4 = b64_index(table, c4)

    match (v1, v2, v3, v4) {
      (Some(b1), Some(b2), Some(b3), Some(b4)) => {
        let byte1 = (b1 << 2) | (b2 >> 4)
        result.write_char(Int::unsafe_to_char(byte1))
        if c3 != '=' {
          let byte2 = ((b2 & 0xF) << 4) | (b3 >> 2)
          result.write_char(Int::unsafe_to_char(byte2))
        }
        if c4 != '=' {
          let byte3 = ((b3 & 0x3) << 6) | b4
          result.write_char(Int::unsafe_to_char(byte3))
        }
      }
      _ => return None
    }
    i = i + 4
  }
  Some(result.to_string())
}

///|
fn b64_index(table : String, c : Char) -> Int? {
  let mut i = 0
  while i < table.length() {
    if table.get_char(i).unwrap() == c {
      return Some(i)
    }
    i = i + 1
  }
  if c == '=' {
    return Some(0)
  }
  None
}
