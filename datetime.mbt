/// RFC 5322 date-time parsing and formatting.
///
/// The Date header in email messages follows the date-time production
/// defined in RFC 5322 section 3.3:
///
///   date-time = [ day-of-week "," ] date time
///   date      = day month year
///   time      = time-of-day [ zone ]
///
/// This module parses such values into the structured EmailDate type
/// and provides validation helpers.

///|
/// Parse an RFC 5322 date-time string into an EmailDate.
///
/// Accepts formats such as:
///   "Mon, 01 Jan 2026 12:34:56 +0800"
///   "1 Jan 2026 12:34:56 GMT"
///   "Tue, 2 Feb 2026 08:00:00 -0500 (EST)"
///
/// Returns None if the value cannot be parsed.
pub fn parse_email_date(input : String) -> EmailDate? {
  let s = input.trim(chars=" \t\r\n").to_owned()
  if s.length() == 0 {
    return None
  }

  // Split into tokens by whitespace
  let tokens = tokenize_ws(s)

  // Find the comma-separated day-of-week prefix if present
  let mut start = 0
  if tokens.length() >= 1 && tokens[0].has_suffix(",") {
    start = 1
  }

  // Now expect: day month year time [zone]
  // Some dates include an obsolete two-digit year or missing time.
  if tokens.length() < start + 4 {
    return None
  }

  // Day of month
  let day_str = tokens[start]
  let day = parse_int(day_str)
  match day {
    None => None
    Some(d) if d >= 1 && d <= 31 => {
      // Month
      let month_str = tokens[start + 1]
      let month = month_name_to_num(month_str)
      match month {
        None => None
        Some(m) => {
          // Year
          let year_str = tokens[start + 2]
          let year = parse_year(year_str)
          match year {
            None => None
            Some(y) => {
              // Time (HH:MM[:SS])
              let time_str = tokens[start + 3]
              let time = parse_time(time_str)
              match time {
                None => None
                Some((hour, minute, second)) => {
                  // Optional zone
                  let tz = if tokens.length() > start + 4 {
                    parse_timezone(tokens[start + 4])
                  } else {
                    Some((0, 0, 1))
                  }
                  match tz {
                    None => None
                    Some((tz_h, tz_m, tz_sign)) =>
                      Some(EmailDate::{
                        year: y,
                        month: m,
                        day: d,
                        hour,
                        minute,
                        second,
                        tz_hour: tz_h,
                        tz_minute: tz_m,
                        tz_sign,
                      })
                  }
                }
              }
            }
          }
        }
      }
    }
    Some(_) => None
  }
}

///|
/// Split a string into whitespace-separated tokens.
fn tokenize_ws(input : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut sb = StringBuilder::new()
  let mut in_token = false
  for c in input {
    if c == ' ' || c == '\t' {
      if in_token {
        tokens.push(sb.to_string())
        sb = StringBuilder::new()
        in_token = false
      }
    } else if c == '(' || c == ')' {
      // Comments: skip everything until matching close paren
      if in_token {
        tokens.push(sb.to_string())
        sb = StringBuilder::new()
        in_token = false
      }
    } else {
      sb.write_char(c)
      in_token = true
    }
  }
  if in_token {
    tokens.push(sb.to_string())
  }
  tokens
}

///|
/// Parse a decimal integer from a string.
fn parse_int(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut result = 0
  let mut i = 0
  let len = s.length()
  let mut started = false
  while i < len {
    let c = s.get_char(i).unwrap()
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
      started = true
    } else {
      return None
    }
    i = i + 1
  }
  if started {
    Some(result)
  } else {
    None
  }
}

///|
/// Parse a year, handling two-digit and four-digit forms.
fn parse_year(s : String) -> Int? {
  let len = s.length()
  if len == 2 {
    let y = parse_int(s)
    match y {
      None => None
      Some(v) =>
        // RFC 5322: two-digit years 00-49 map to 2000-2049,
        // 50-99 map to 1950-1999.
        if v >= 50 {
          Some(1900 + v)
        } else {
          Some(2000 + v)
        }
    }
  } else if len == 4 {
    parse_int(s)
  } else {
    None
  }
}

///|
/// Parse a time of day "HH:MM[:SS]".
fn parse_time(s : String) -> (Int, Int, Int)? {
  let parts = split_char(s, ':')
  if parts.length() < 2 {
    return None
  }
  let hour = parse_int(parts[0])
  let minute = parse_int(parts[1])
  let second = if parts.length() >= 3 { parse_int(parts[2]) } else { Some(0) }
  match (hour, minute, second) {
    (Some(h), Some(m), Some(sec)) =>
      if h >= 0 && h <= 23 && m >= 0 && m <= 59 && sec >= 0 && sec <= 60 {
        Some((h, m, sec))
      } else {
        None
      }
    _ => None
  }
}

///|
/// Split a string by a delimiter character into an array of strings.
fn split_char(s : String, delim : Char) -> Array[String] {
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

///|
/// Map a three-letter month abbreviation to its number (1-12).
fn month_name_to_num(s : String) -> Int? {
  let lower = s.to_lower()
  if lower == "jan" {
    Some(1)
  } else if lower == "feb" {
    Some(2)
  } else if lower == "mar" {
    Some(3)
  } else if lower == "apr" {
    Some(4)
  } else if lower == "may" {
    Some(5)
  } else if lower == "jun" {
    Some(6)
  } else if lower == "jul" {
    Some(7)
  } else if lower == "aug" {
    Some(8)
  } else if lower == "sep" {
    Some(9)
  } else if lower == "oct" {
    Some(10)
  } else if lower == "nov" {
    Some(11)
  } else if lower == "dec" {
    Some(12)
  } else {
    None
  }
}

///|
/// Parse a timezone token into (hour, minute, sign).
/// Supports numeric offsets (+0800, -0500, +05:30) and named zones.
fn parse_timezone(s : String) -> (Int, Int, Int)? {
  if s.length() == 0 {
    return Some((0, 0, 1))
  }

  // Named zones
  let upper = s.to_upper()
  match upper {
    "UT" | "UTC" | "GMT" | "Z" => return Some((0, 0, 1))
    "EST" => return Some((5, 0, -1))
    "EDT" => return Some((4, 0, -1))
    "CST" => return Some((6, 0, -1))
    "CDT" => return Some((5, 0, -1))
    "MST" => return Some((7, 0, -1))
    "MDT" => return Some((6, 0, -1))
    "PST" => return Some((8, 0, -1))
    "PDT" => return Some((7, 0, -1))
    _ => ()
  }

  // Numeric zone: sign + 4 digits (HHMM) or sign + HH:MM
  if s.length() < 2 {
    return None
  }
  let sign_char = s.get_char(0).unwrap()
  let sign = if sign_char == '-' {
    -1
  } else if sign_char == '+' {
    1
  } else {
    return None
  }
  let rest = s.unsafe_substring(start=1, end=s.length())

  if rest.length() == 4 {
    let hh = parse_int(rest.unsafe_substring(start=0, end=2))
    let mm = parse_int(rest.unsafe_substring(start=2, end=4))
    match (hh, mm) {
      (Some(h), Some(m)) =>
        if h <= 23 && m <= 59 {
          Some((h, m, sign))
        } else {
          None
        }
      _ => None
    }
  } else if rest.contains(":") {
    let parts = split_char(rest, ':')
    if parts.length() == 2 {
      let hh = parse_int(parts[0])
      let mm = parse_int(parts[1])
      match (hh, mm) {
        (Some(h), Some(m)) =>
          if h <= 23 && m <= 59 {
            Some((h, m, sign))
          } else {
            None
          }
        _ => None
      }
    } else {
      None
    }
  } else {
    None
  }
}

///|
/// Validate a parsed EmailDate: checks ranges and month/day consistency.
pub fn validate_date(d : EmailDate) -> Bool {
  if d.month < 1 || d.month > 12 {
    return false
  }
  if d.day < 1 || d.day > days_in_month(d.year, d.month) {
    return false
  }
  if d.hour < 0 || d.hour > 23 {
    return false
  }
  if d.minute < 0 || d.minute > 59 {
    return false
  }
  if d.second < 0 || d.second > 60 {
    return false
  }
  if d.tz_hour < 0 || d.tz_hour > 23 || d.tz_minute < 0 || d.tz_minute > 59 {
    return false
  }
  true
}

///|
/// Get the number of days in a given month, accounting for leap years.
pub fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
}

///|
/// Check whether a year is a leap year.
pub fn is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
/// Get the numeric timezone offset of an EmailDate in minutes.
pub fn tz_offset_minutes(d : EmailDate) -> Int {
  (d.tz_hour * 60 + d.tz_minute) * d.tz_sign
}

///|
/// Convert an EmailDate to a Unix-like timestamp (seconds since epoch).
/// Uses a simplified days-from-civil algorithm.
pub fn to_timestamp(d : EmailDate) -> Int {
  let y = if d.month <= 2 { d.year - 1 } else { d.year }
  let y_base = if y >= 0 { y } else { y - 399 }
  let era = y_base / 400
  let yoe = y - era * 400
  let mp = (d.month + 9) % 12
  let doy = (153 * mp + 2) / 5 + d.day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  let days = era * 146097 + doe - 719468
  days * 86400 +
  d.hour * 3600 +
  d.minute * 60 +
  d.second -
  tz_offset_minutes(d) * 60
}

///|
/// Parse a Date header value from a Message and return the EmailDate.
pub fn parse_date_header(value : String) -> EmailDate? {
  parse_email_date(value)
}

///|
/// Get the parsed Date from a Message, if present and valid.
pub fn message_date(msg : Message) -> EmailDate? {
  let value = get_header(msg, "Date")
  match value {
    None => None
    Some(v) => parse_email_date(v)
  }
}

///|
/// Format an EmailDate in RFC 5322 format with full weekday.
pub fn format_rfc5322_date(d : EmailDate) -> String {
  email_date_to_string(d)
}

///|
/// Compare two EmailDates: returns -1, 0, or 1 based on their timestamps.
pub fn compare_dates(a : EmailDate, b : EmailDate) -> Int {
  let ta = to_timestamp(a)
  let tb = to_timestamp(b)
  if ta < tb {
    -1
  } else if ta > tb {
    1
  } else {
    0
  }
}
