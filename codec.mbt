/// Content-Transfer-Encoding codecs for MIME bodies.
///
/// Implements the two standard MIME content transfer encodings
/// defined in RFC 2045 section 6:
///   - Base64 (section 6.8)
///   - Quoted-Printable (section 6.7)
///
/// All public functions use the b64_ / qp_ prefixes to avoid name
/// collisions with internal helpers in other modules.

///|
/// Encode a byte sequence as Base64, with 76-character line wrapping.
pub fn b64_encode_bytes(data : Array[Int]) -> String {
  let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let sb = StringBuilder::new()
  let len = data.length()
  let mut col = 0
  let mut i = 0
  while i < len {
    let b1 = data[i] & 0xFF
    let b2 = if i + 1 < len { data[i + 1] & 0xFF } else { 0 }
    let b3 = if i + 2 < len { data[i + 2] & 0xFF } else { 0 }

    let c1 = (b1 >> 2) & 0x3F
    let c2 = ((b1 << 4) | (b2 >> 4)) & 0x3F
    let c3 = if i + 1 < len { ((b2 << 2) | (b3 >> 6)) & 0x3F } else { 64 }
    let c4 = if i + 2 < len { b3 & 0x3F } else { 64 }

    sb.write_char(table.get_char(c1).unwrap())
    sb.write_char(table.get_char(c2).unwrap())
    sb.write_char(if i + 1 < len { table.get_char(c3).unwrap() } else { '=' })
    sb.write_char(if i + 2 < len { table.get_char(c4).unwrap() } else { '=' })

    col = col + 4
    if col >= 76 && i + 3 < len {
      sb.write_string("\r\n")
      col = 0
    }
    i = i + 3
  }
  sb.to_string()
}

///|
/// Decode a Base64 string into a byte sequence.
/// Returns None if the input is not valid Base64.
pub fn b64_decode_bytes(input : String) -> Array[Int]? {
  let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let compact = strip_b64_ws(input)
  let len = compact.length()
  if len % 4 != 0 {
    return None
  }
  let result : Array[Int] = []
  let mut i = 0
  while i < len {
    let c1 = compact.get_char(i).unwrap()
    let c2 = compact.get_char(i + 1).unwrap()
    let c3 = compact.get_char(i + 2).unwrap()
    let c4 = compact.get_char(i + 3).unwrap()

    let v1 = b64_index_of(table, c1)
    let v2 = b64_index_of(table, c2)
    let v3 = b64_index_of(table, c3)
    let v4 = b64_index_of(table, c4)

    match (v1, v2, v3, v4) {
      (Some(b1), Some(b2), Some(b3), Some(b4)) => {
        let byte1 = (b1 << 2) | (b2 >> 4)
        result.push(byte1)
        if c3 != '=' {
          let byte2 = ((b2 & 0xF) << 4) | (b3 >> 2)
          result.push(byte2)
        }
        if c4 != '=' {
          let byte3 = ((b3 & 0x3) << 6) | b4
          result.push(byte3)
        }
      }
      _ => return None
    }
    i = i + 4
  }
  Some(result)
}

///|
/// Decode a Base64 string into a text string (Latin-1 mapping).
pub fn b64_decode_text(input : String) -> String? {
  let bytes = b64_decode_bytes(input)
  match bytes {
    None => None
    Some(bs) => {
      let sb = StringBuilder::new()
      for b in bs {
        sb.write_char(Int::unsafe_to_char(b))
      }
      Some(sb.to_string())
    }
  }
}

///|
/// Encode a text string as Base64 using Latin-1 mapping.
pub fn b64_encode_text(s : String) -> String {
  let bytes : Array[Int] = []
  for c in s {
    bytes.push(c.to_int())
  }
  b64_encode_bytes(bytes)
}

///|
/// Encode a byte sequence as Quoted-Printable (RFC 2045 6.7).
/// Non-printable bytes and '=' are escaped as =XX. Soft line breaks
/// are inserted at 75 columns.
pub fn qp_encode_bytes(data : Array[Int]) -> String {
  let sb = StringBuilder::new()
  let len = data.length()
  let mut col = 0
  let mut i = 0
  while i < len {
    let b = data[i] & 0xFF
    // Check if this byte needs escaping
    let printable = (b >= 33 && b <= 60) || (b >= 62 && b <= 126)
    if printable {
      // Need to check for line length soft break
      if col >= 75 {
        sb.write_string("=\r\n")
        col = 0
      }
      sb.write_char(Int::unsafe_to_char(b))
      col = col + 1
    } else if b == 9 || b == 32 {
      // Tab and space: only escape if at end of line (conservative)
      if col >= 75 {
        sb.write_string("=\r\n")
        col = 0
      }
      sb.write_char(Int::unsafe_to_char(b))
      col = col + 1
    } else {
      if col >= 74 {
        sb.write_string("=\r\n")
        col = 0
      }
      sb.write_string("=")
      sb.write_string(hex_byte_upper(b))
      col = col + 3
    }
    i = i + 1
  }
  sb.to_string()
}

///|
/// Encode a text string as Quoted-Printable.
pub fn qp_encode_text(s : String) -> String {
  let bytes : Array[Int] = []
  for c in s {
    bytes.push(c.to_int())
  }
  qp_encode_bytes(bytes)
}

///|
/// Decode a Quoted-Printable encoded string (RFC 2045 6.7).
/// Handles soft line breaks (=CRLF, =LF) and hex escapes (=XX).
pub fn qp_decode(input : String) -> String? {
  let sb = StringBuilder::new()
  let len = input.length()
  let mut i = 0
  while i < len {
    let c = input.get_char(i).unwrap()
    if c == '=' {
      // Soft line break
      if i + 1 < len && input.get_char(i + 1).unwrap() == '\n' {
        i = i + 2
        continue
      } else if i + 2 < len &&
        input.get_char(i + 1).unwrap() == '\r' &&
        input.get_char(i + 2).unwrap() == '\n' {
        i = i + 3
        continue
      } else if i + 2 < len {
        let byte = hex_char_to_int(input.get_char(i + 1).unwrap())
        match byte {
          Some(b1) => {
            let b2 = hex_char_to_int(input.get_char(i + 2).unwrap())
            match b2 {
              Some(l) => {
                sb.write_char(Int::unsafe_to_char(b1 * 16 + l))
                i = i + 3
                continue
              }
              None => ()
            }
          }
          None => ()
        }
        // Invalid escape: pass '=' through
        sb.write_char('=')
        i = i + 1
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

///|
/// Convert a hex character to its integer value (0-15).
pub fn hex_char_to_int(c : Char) -> Int? {
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

///|
/// Format a byte as two uppercase hex digits.
fn hex_byte_upper(b : Int) -> String {
  let digits = "0123456789ABCDEF"
  let hi = (b >> 4) & 0xF
  let lo = b & 0xF
  let sb = StringBuilder::new()
  sb.write_char(digits.get_char(hi).unwrap())
  sb.write_char(digits.get_char(lo).unwrap())
  sb.to_string()
}

///|
/// Strip whitespace and '=' padding artifacts from a Base64 string.
fn strip_b64_ws(input : String) -> String {
  let sb = StringBuilder::new()
  for c in input {
    if c != ' ' && c != '\t' && c != '\r' && c != '\n' {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Find the index of a Base64 character in the standard alphabet.
fn b64_index_of(table : String, c : Char) -> Int? {
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

///|
/// Check whether a string contains only ASCII characters (0-127).
pub fn is_ascii_only(s : String) -> Bool {
  for c in s {
    if c.to_int() > 127 {
      return false
    }
  }
  true
}

///|
/// Check whether a string is valid printable ASCII text.
pub fn is_printable_ascii(s : String) -> Bool {
  for c in s {
    let v = c.to_int()
    if v < 32 && v != 9 && v != 10 && v != 13 {
      return false
    }
    if v > 126 {
      return false
    }
  }
  true
}

///|
/// Encode a non-ASCII string using RFC 2047 encoded-word Base64 form.
/// Only encodes if the input contains non-ASCII characters.
pub fn encode_encoded_word_b(s : String) -> String {
  if is_ascii_only(s) {
    return s
  }
  let encoded = b64_encode_text(s)
  "=?UTF-8?B?" + encoded + "?="
}

///|
/// Encode a non-ASCII string using RFC 2047 encoded-word Q form.
/// Spaces become '_' in the encoded form.
pub fn encode_encoded_word_q(s : String) -> String {
  if is_ascii_only(s) {
    return s
  }
  let sb = StringBuilder::new()
  for c in s {
    let v = c.to_int()
    if v > 127 || c == '=' || c == '?' || c == '_' {
      sb.write_string("=")
      sb.write_string(hex_byte_upper(v))
    } else if c == ' ' {
      sb.write_char('_')
    } else {
      sb.write_char(c)
    }
  }
  "=?UTF-8?Q?" + sb.to_string() + "?="
}
