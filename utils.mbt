/// General-purpose utilities for email processing.
///
/// Provides UTF-8 codec helpers, HTML escaping, URL encoding for
/// RFC 2231 compatibility, case-insensitive string operations, and
/// charset detection used across the library.

/// Encode a string as UTF-8 bytes, returning an array of bytes.
/// Non-ASCII characters are encoded as 2-4 byte sequences.
pub fn utf8_encode(s : String) -> Array[Int] {
  let result : Array[Int] = []
  for c in s {
    let cp = c.to_int()
    if cp <= 0x7F {
      result.push(cp)
    } else if cp <= 0x7FF {
      result.push(0xC0 | (cp >> 6))
      result.push(0x80 | (cp & 0x3F))
    } else if cp <= 0xFFFF {
      result.push(0xE0 | (cp >> 12))
      result.push(0x80 | ((cp >> 6) & 0x3F))
      result.push(0x80 | (cp & 0x3F))
    } else {
      result.push(0xF0 | (cp >> 18))
      result.push(0x80 | ((cp >> 12) & 0x3F))
      result.push(0x80 | ((cp >> 6) & 0x3F))
      result.push(0x80 | (cp & 0x3F))
    }
  }
  result
}

/// Decode UTF-8 bytes into a string.
/// Returns the decoded string; invalid sequences become replacement chars.
pub fn utf8_decode(bytes : Array[Int]) -> String {
  let sb = StringBuilder::new()
  let len = bytes.length()
  let mut i = 0
  while i < len {
    let b = bytes[i] & 0xFF
    if b < 0x80 {
      sb.write_char(Int::unsafe_to_char(b))
      i = i + 1
    } else if b >= 0xC0 && b <= 0xDF && i + 1 < len {
      let cp = ((b & 0x1F) << 6) | (bytes[i + 1] & 0x3F)
      sb.write_char(Int::unsafe_to_char(cp))
      i = i + 2
    } else if b >= 0xE0 && b <= 0xEF && i + 2 < len {
      let cp = ((b & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) |
               (bytes[i + 2] & 0x3F)
      sb.write_char(Int::unsafe_to_char(cp))
      i = i + 3
    } else if b >= 0xF0 && b <= 0xF7 && i + 3 < len {
      let cp = ((b & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) |
               ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F)
      sb.write_char(Int::unsafe_to_char(cp))
      i = i + 4
    } else {
      // Invalid byte: replacement character
      sb.write_char('?')
      i = i + 1
    }
  }
  sb.to_string()
}

/// Escape a string for inclusion in HTML content.
pub fn html_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    match c {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '"' => sb.write_string("&quot;")
      '\'' => sb.write_string("&#39;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

/// Decode common HTML entities back to characters.
pub fn html_unescape(s : String) -> String {
  let sb = StringBuilder::new()
  let len = s.length()
  let mut i = 0
  while i < len {
    let c = s.get_char(i).unwrap()
    if c == '&' && i + 3 < len {
      let next = s.unsafe_substring(start=i, end=i + 4)
      if next == "&lt;" { sb.write_char('<'); i = i + 4; continue }
      if next == "&gt;" { sb.write_char('>'); i = i + 4; continue }
      if i + 4 < len {
        let next5 = s.unsafe_substring(start=i, end=i + 5)
        if next5 == "&amp;" { sb.write_char('&'); i = i + 5; continue }
        if next5 == "&quot;" { sb.write_char('"'); i = i + 5; continue }
      }
      if i + 5 < len {
        let next6 = s.unsafe_substring(start=i, end=i + 6)
        if next6 == "&#39;" { sb.write_char('\''); i = i + 6; continue }
      }
    }
    sb.write_char(c)
    i = i + 1
  }
  sb.to_string()
}

/// URL-encode a string (percent-encoding) for RFC 2231 parameters.
/// Spaces become %20; unreserved characters pass through.
pub fn url_encode(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    let v = c.to_int()
    let unreserved = (v >= 'a'.to_int() && v <= 'z'.to_int()) ||
                     (v >= 'A'.to_int() && v <= 'Z'.to_int()) ||
                     (v >= '0'.to_int() && v <= '9'.to_int()) ||
                     c == '-' || c == '_' || c == '.' || c == '~'
    if unreserved {
      sb.write_char(c)
    } else {
      sb.write_string("%")
      sb.write_string(byte_hex(v))
    }
  }
  sb.to_string()
}

/// Format a byte as two uppercase hex digits.
fn byte_hex(b : Int) -> String {
  let digits = "0123456789ABCDEF"
  let hi = (b >> 4) & 0xF
  let lo = b & 0xF
  let sb = StringBuilder::new()
  sb.write_char(digits.get_char(hi).unwrap())
  sb.write_char(digits.get_char(lo).unwrap())
  sb.to_string()
}

/// Case-insensitive string comparison.
pub fn eq_ignore_case(a : String, b : String) -> Bool {
  a.to_lower() == b.to_lower()
}

/// Case-insensitive prefix check.
pub fn starts_with_ignore_case(s : String, prefix : String) -> Bool {
  s.to_lower().has_prefix(prefix.to_lower())
}

/// Check whether a string is a valid email header name.
pub fn valid_header_name(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  for c in name {
    let v = c.to_int()
    let ok = (v >= 'a'.to_int() && v <= 'z'.to_int()) ||
             (v >= 'A'.to_int() && v <= 'Z'.to_int()) ||
             (v >= '0'.to_int() && v <= '9'.to_int()) ||
             c == '-'
    if !ok {
      return false
    }
  }
  true
}

/// Detect the character set name from a Content-Type parameter.
/// Returns "us-ascii" as the default.
pub fn detect_charset(params : Array[(String, String)]) -> String {
  for pi = 0; pi < params.length(); pi = pi + 1 {
    let (k, v) = params[pi]
    if k == "charset" {
      return v.to_lower()
    }
  }
  "us-ascii"
}

/// Convert a charset name to a canonical lowercase form.
pub fn canonical_charset(name : String) -> String {
  let lower = name.to_lower()
  if lower == "utf8" || lower == "utf-8" { "utf-8" }
  else if lower == "ascii" || lower == "us-ascii" || lower == "ansi_x3.4-1968" { "us-ascii" }
  else if lower == "gbk" || lower == "gb2312" || lower == "gb-2312" { "gbk" }
  else if lower == "iso-8859-1" || lower == "latin1" || lower == "latin-1" { "iso-8859-1" }
  else { lower }
}

/// Check whether a charset is a single-byte ASCII-compatible encoding.
pub fn is_ascii_compatible_charset(name : String) -> Bool {
  let c = canonical_charset(name)
  c == "us-ascii" || c == "iso-8859-1"
}

/// Convert an HTML string to plain text by stripping tags.
pub fn html_to_text(html : String) -> String {
  let sb = StringBuilder::new()
  let len = html.length()
  let mut i = 0
  let mut in_tag = false
  while i < len {
    let c = html.get_char(i).unwrap()
    if c == '<' {
      in_tag = true
    } else if c == '>' {
      in_tag = false
    } else if !in_tag {
      sb.write_char(c)
    }
    i = i + 1
  }
  // Decode entities and collapse whitespace
  let decoded = html_unescape(sb.to_string())
  collapse_ws(decoded)
}

/// Collapse runs of whitespace into single spaces.
pub fn collapse_ws(s : String) -> String {
  let sb = StringBuilder::new()
  let mut prev_ws = false
  for c in s {
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      if !prev_ws {
        sb.write_char(' ')
        prev_ws = true
      }
    } else {
      sb.write_char(c)
      prev_ws = false
    }
  }
  sb.to_string().trim(chars=" ").to_owned()
}

/// Convert a body to a safe plain-text form for display.
pub fn sanitize_text(s : String) -> String {
  html_unescape(s)
}

/// Quote a string for use in a quoted-string header value.
pub fn quote_header_string(s : String) -> String {
  let escaped = s.replace_all(old="\\", new="\\\\")
  let escaped2 = escaped.replace_all(old="\"", new="\\\"")
  "\"" + escaped2 + "\""
}

/// Check whether a string is a valid IPv4 domain literal.
pub fn is_ipv4(s : String) -> Bool {
  let parts = split_by_char(s, '.')
  if parts.length() != 4 {
    return false
  }
  for p in parts {
    if p.length() == 0 || p.length() > 3 {
      return false
    }
    let mut sum = 0
    for c in p {
      if c < '0' || c > '9' {
        return false
      }
      sum = sum * 10 + (c.to_int() - '0'.to_int())
    }
    if sum > 255 {
      return false
    }
  }
  true
}

/// Split a string by a delimiter character into an array of strings.
fn split_by_char(s : String, delim : Char) -> Array[String] {
  let parts : Array[String] = []
  let mut sb = StringBuilder::new()
  for c in s {
    if c == delim {
      parts.push(sb.to_string())
      sb = StringBuilder::new()
    } else {
      sb.write_char(c)
    }
  }
  parts.push(sb.to_string())
  parts
}

/// Truncate a string to a maximum length, appending "..." if truncated.
pub fn truncate(s : String, max_len : Int) -> String {
  if s.length() <= max_len {
    s
  } else if max_len <= 3 {
    s.unsafe_substring(start=0, end=max_len)
  } else {
    s.unsafe_substring(start=0, end=max_len - 3) + "..."
  }
}

/// Compute a simple non-cryptographic hash of a string (for indexing).
pub fn simple_hash(s : String) -> Int {
  let mut h = 5381
  for c in s {
    h = ((h << 5) + h) + c.to_int()
    h = h & 0x7FFFFFFF
  }
  h
}

/// Check whether two messages have the same Message-ID.
pub fn same_message(a : Message, b : Message) -> Bool {
  let ida = message_message_id(a)
  let idb = message_message_id(b)
  match (ida, idb) {
    (Some(x), Some(y)) => x.id == y.id && x.domain == y.domain
    _ => false
  }
}
