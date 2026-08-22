/// Header value decoding: RFC 2047 encoded-words and RFC 2231 parameters.
///
/// RFC 2047 (MIME Part Three) defines encoded-words for representing
/// non-ASCII text in header fields:
///
///   encoded-word = "=?" charset "?" encoding "?" encoded-text "?="
///
/// RFC 2231 (MIME Parameter Value and Encoded Word Extensions) defines
/// the parameter value continuation and character-set extensions used
/// in Content-Type / Content-Disposition headers:
///
///   filename*=UTF-8''%E4%B8%AD%E6%96%87.txt
///   filename*0*=UTF-8''%E4%B8%AD; filename*1*=%E6%96%87.txt
///
/// This module provides full decoding for both mechanisms.

///|
/// Decode all RFC 2047 encoded-words in a header value.
///
/// Adjacent encoded-words are concatenated without a separator,
/// while a regular space between encoded-words is collapsed.
/// Non-encoded text is passed through unchanged.
pub fn decode_header_value(input : String) -> String {
  let s = input.trim(chars=" \t\r\n").to_owned()
  let sb = StringBuilder::new()
  let len = s.length()
  let mut i = 0
  let mut last_was_encoded = false

  while i < len {
    // Check for encoded-word start
    if i + 2 < len &&
      s.get_char(i).unwrap() == '=' &&
      s.get_char(i + 1).unwrap() == '?' {
      // Find the closing ?=
      let end = find_encoded_end(s, i + 2)
      match end {
        None => {
          // No closing sequence: write rest as-is
          sb.write_string(s.unsafe_substring(start=i, end=len))
          break
        }
        Some(close_pos) => {
          let word = s.unsafe_substring(start=i, end=close_pos + 2)
          let decoded = decode_encoded_word(word)
          match decoded {
            Some(text) => {
              // Collapse a space before an encoded-word if the previous
              // token was also an encoded-word or the space is inside
              if !last_was_encoded && sb.to_string().has_suffix(" ") {
                // Remove the trailing space: handle in write below
              }
              sb.write_string(text)
              last_was_encoded = true
            }
            None => {
              sb.write_string(word)
              last_was_encoded = false
            }
          }
          i = close_pos + 2
          // Skip a single space between two encoded-words
          if i < len && s.get_char(i).unwrap() == ' ' {
            // Peek: if next is another encoded-word, skip the space
            if i + 1 < len &&
              s.get_char(i + 1).unwrap() == '=' &&
              s.get_char(i + 2).unwrap() == '?' {
              i = i + 1
            } else {
              sb.write_char(' ')
              i = i + 1
            }
          }
          continue
        }
      }
    }
    sb.write_char(s.get_char(i).unwrap())
    last_was_encoded = false
    i = i + 1
  }

  sb.to_string()
}

///|
/// Find the position of the closing "?=" of an encoded-word starting at
/// the "?..." part. Returns the index of the last '='.
fn find_encoded_end(s : String, start : Int) -> Int? {
  let len = s.length()
  let mut i = start
  while i + 1 < len {
    if s.get_char(i).unwrap() == '?' && s.get_char(i + 1).unwrap() == '=' {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Decode a single RFC 2231 extended parameter value.
///
/// Handles the charset and language prefix: "UTF-8''..." where the
/// remainder is percent-encoded.
pub fn decode_rfc2231_value(input : String) -> String? {
  let s = input.trim(chars=" \t").to_owned()
  // Look for the charset'language' prefix
  let q1 = s.find("'")
  match q1 {
    None =>
      // No charset prefix: percent-decode the whole value
      percent_decode(s)
    Some(p1) => {
      // charset before p1
      let charset = s.unsafe_substring(start=0, end=p1).to_upper()
      let rest = s.unsafe_substring(start=p1 + 1, end=s.length())
      let q2 = rest.find("'")
      match q2 {
        None => percent_decode(rest)
        Some(p2) => {
          let lang = rest.unsafe_substring(start=0, end=p2)
          ignore(lang)
          let encoded = rest.unsafe_substring(start=p2 + 1, end=rest.length())
          let decoded = percent_decode(encoded)
          match decoded {
            Some(text) => Some(text)
            None =>
              // Fall back to raw if charset is not UTF-8
              if charset == "UTF-8" {
                None
              } else {
                Some(encoded)
              }
          }
        }
      }
    }
  }
}

///|
/// Percent-decode a string: %XX sequences become their byte values.
/// Multi-byte UTF-8 sequences are decoded into Unicode characters.
pub fn percent_decode(input : String) -> String? {
  let bytes : Array[Int] = []
  let len = input.length()
  let mut i = 0
  while i < len {
    let c = input.get_char(i).unwrap()
    if c == '%' {
      if i + 2 < len {
        let h1 = input.get_char(i + 1).unwrap()
        let h2 = input.get_char(i + 2).unwrap()
        let byte = hex_pair(h1, h2)
        match byte {
          Some(b) => {
            bytes.push(b)
            i = i + 3
            continue
          }
          None => ()
        }
      }
      bytes.push(c.to_int())
      i = i + 1
    } else {
      bytes.push(c.to_int())
      i = i + 1
    }
  }
  Some(utf8_decode(bytes))
}

///|
/// Convert two hex characters to a byte value.
fn hex_pair(h1 : Char, h2 : Char) -> Int? {
  let hi = hex_char_to_int(h1)
  let lo = hex_char_to_int(h2)
  match (hi, lo) {
    (Some(a), Some(b)) => Some(a * 16 + b)
    _ => None
  }
}

///|
/// Merge RFC 2231 parameter continuations into complete parameter values.
///
/// Handles both:
///   - Single-part extended values: name*=charset'lang'value
///   - Continued values: name*0*=..., name*1*=..., name*2=...
pub fn merge_extended_params(
  params : Array[(String, String)],
) -> Array[(String, String)] {
  let results : Array[(String, String)] = []

  // First pass: collect regular (non-extended) parameters
  let mut i = 0
  while i < params.length() {
    let (k, v) = params[i]
    if !k.contains("*") {
      results.push((k, v))
    }
    i = i + 1
  }

  // Second pass: collect extended parameters by base name
  let seen : Array[String] = []
  let mut j = 0
  while j < params.length() {
    let (k, _) = params[j]
    if k.contains("*") {
      // Extract base name: strip *N* or * suffixes
      let base = base_param_name(k)
      if !seen.contains(base) {
        seen.push(base)
        let value = join_continuations(params, base)
        match value {
          Some(decoded) => results.push((base, decoded))
          None => ()
        }
      }
    }
    j = j + 1
  }

  results
}

///|
/// Extract the base parameter name from an extended name.
/// "filename*0*" -> "filename", "name*" -> "name"
fn base_param_name(key : String) -> String {
  let star = key.find("*")
  match star {
    None => key
    Some(pos) => key.unsafe_substring(start=0, end=pos)
  }
}

///|
/// Join all continuation segments of an extended parameter and decode.
fn join_continuations(
  params : Array[(String, String)],
  base : String,
) -> String? {
  // Collect segments with their sequence numbers
  let segments : Array[(Int, String)] = []

  let mut i = 0
  while i < params.length() {
    let (k, v) = params[i]
    let kk = k.to_lower()
    if kk == base + "*" {
      // Single-part extended value (no segment number)
      segments.push((-1, v))
    } else if kk.has_prefix(base + "*") {
      // Segmented: base*N* or base*N
      let rest = kk.unsafe_substring(start=base.length() + 1, end=kk.length())
      let num_parts = split_char(rest, '*')
      if num_parts.length() >= 1 {
        let num = num_parts[0]
        match parse_num(num) {
          Some(n) => segments.push((n, v))
          None => ()
        }
      }
    }
    i = i + 1
  }

  if segments.length() == 0 {
    return None
  }

  // Sort by segment number
  sort_segments(segments)

  // Concatenate raw parts
  let raw = StringBuilder::new()
  for si = 0; si < segments.length(); si = si + 1 {
    raw.write_string(segments[si].1)
  }

  // Decode: first segment may carry the charset prefix
  let combined = raw.to_string()
  let first = segments[0]
  if first.0 == -1 || segments.length() == 1 {
    decode_rfc2231_value(combined)
  } else {
    // First segment may have charset'lang' prefix; decode whole
    decode_rfc2231_value(combined)
  }
}

///|
/// Parse a small integer from a string.
fn parse_num(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      return None
    }
  }
  Some(result)
}

///|
/// Sort (Int, String) pairs by the integer in ascending order (insertion sort).
fn sort_segments(segments : Array[(Int, String)]) -> Unit {
  let mut i = 1
  while i < segments.length() {
    let mut j = i
    while j > 0 && segments[j - 1].0 > segments[j].0 {
      let tmp = segments[j - 1]
      segments[j - 1] = segments[j]
      segments[j] = tmp
      j = j - 1
    }
    i = i + 1
  }
}

///|
/// Decode a Content-Type header with RFC 2231 extended parameters.
pub fn decode_content_type(value : String) -> ContentType? {
  let ct = parse_content_type(value)
  match ct {
    None => None
    Some(c) => {
      let merged = merge_extended_params(c.params)
      Some(ContentType::{
        media_type: c.media_type,
        sub_type: c.sub_type,
        params: merged,
      })
    }
  }
}

///|
/// Decode a Content-Disposition header with RFC 2231 extended parameters.
pub fn decode_content_disposition(value : String) -> ContentDisposition? {
  let cd = parse_content_disposition(value)
  match cd {
    None => None
    Some(d) => {
      let merged = merge_extended_params(d.params)
      Some(ContentDisposition::{ disposition: d.disposition, params: merged })
    }
  }
}

///|
/// Get a decoded filename from a Content-Disposition, handling RFC 2231.
pub fn decoded_filename(cd : ContentDisposition) -> String? {
  // Prefer the extended filename parameter
  let mut found : String? = None
  for i = 0; i < cd.params.length(); i = i + 1 {
    let (k, v) = cd.params[i]
    if k == "filename" {
      found = Some(v)
    }
  }
  found
}

///|
/// Check whether a header value contains any RFC 2047 encoded-word.
pub fn has_encoded_words(input : String) -> Bool {
  input.contains("=?") && input.contains("?=")
}

///|
/// Count the number of encoded-words in a header value.
pub fn count_encoded_words(input : String) -> Int {
  let mut count = 0
  let len = input.length()
  let mut i = 0
  while i + 1 < len {
    if input.get_char(i).unwrap() == '=' &&
      input.get_char(i + 1).unwrap() == '?' {
      // Skip past the encoded-word
      let end = find_encoded_end(input, i + 2)
      match end {
        Some(close) => {
          count = count + 1
          i = close + 2
          continue
        }
        None => ()
      }
    }
    i = i + 1
  }
  count
}

///|
/// Strip comments (parenthesized text) from a header value.
pub fn strip_comments(input : String) -> String {
  let sb = StringBuilder::new()
  let mut depth = 0
  let mut in_quote = false
  for c in input {
    if c == '"' && depth == 0 {
      in_quote = !in_quote
      sb.write_char(c)
    } else if c == '(' && !in_quote {
      depth = depth + 1
    } else if c == ')' && !in_quote {
      if depth > 0 {
        depth = depth - 1
      }
    } else if depth == 0 {
      sb.write_char(c)
    }
  }
  collapse_ws(sb.to_string())
}
