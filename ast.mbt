/// Email and MIME AST types for mbt-email.
///
/// Defines the core data structures for representing parsed email messages,
/// email addresses, headers, and MIME parts.

/// A parsed email address: local-part@domain
pub struct EmailAddress {
  local_part : String
  domain : String
}

/// An email header: name and raw value.
pub struct Header {
  name : String
  value : String
}

/// A MIME content-type with media type, subtype, and parameters.
pub struct ContentType {
  media_type : String
  sub_type : String
  params : Array[(String, String)]
}

/// A MIME content-disposition (inline or attachment).
pub struct ContentDisposition {
  disposition : String
  params : Array[(String, String)]
}

/// A MIME body part.
pub enum Body {
  /// Plain text body
  Text(String)
  /// Binary body (e.g., base64-decoded attachment)
  Binary(Bytes)
  /// Multipart body (nested MIME parts)
  Multipart(Array[MimePart])
}

/// A MIME part: headers + body.
pub struct MimePart {
  headers : Array[Header]
  body : Body
}

/// A parsed email message with headers and optional MIME body.
pub struct Message {
  headers : Array[Header]
  body : String?
  mime_part : MimePart?
}


/// Look up a header by name (case-insensitive).
/// Returns None if the header is not found.
pub fn get_header(msg : Message, name : String) -> String? {
  let lower = name.to_lower()
  for header in msg.headers {
    if header.name.to_lower() == lower {
      return Some(header.value)
    }
  }
  None
}

/// Look up all headers matching a name (case-insensitive).
pub fn get_headers(msg : Message, name : String) -> Array[String] {
  let lower = name.to_lower()
  let results : Array[String] = []
  for header in msg.headers {
    if header.name.to_lower() == lower {
      results.push(header.value)
    }
  }
  results
}

/// Create a new empty message.
pub fn empty_message() -> Message {
  Message::{ headers: [], body: None, mime_part: None }
}

/// Create a simple text email address.
pub fn email_address(local_part~ : String, domain~ : String) -> EmailAddress {
  EmailAddress::{ local_part, domain }
}

/// Create a new header.
pub fn header(name~ : String, value~ : String) -> Header {
  Header::{ name, value }
}

/// Create a new text-only MIME part.
pub fn text_part(body~ : String) -> MimePart {
  MimePart::{
    headers: [
      Header::{ name: "Content-Type", value: "text/plain" },
    ],
    body: Body::Text(body),
  }
}

/// Create a new multipart MIME part.
pub fn multipart_part(sub_type~ : String, boundary~ : String, parts~ : Array[MimePart]) -> MimePart {
  MimePart::{
    headers: [
      Header::{
        name: "Content-Type",
        value: "multipart/" + sub_type + "; boundary=\"" + boundary + "\"",
      },
    ],
    body: Body::Multipart(parts),
  }
}

/// Create a new attachment MIME part.
pub fn attachment_part(
  body~ : Bytes,
  filename~ : String,
  mime_type~ : String = "application/octet-stream",
) -> MimePart {
  MimePart::{
    headers: [
      Header::{
        name: "Content-Type",
        value: mime_type + "; name=\"" + filename + "\"",
      },
      Header::{
        name: "Content-Disposition",
        value: "attachment; filename=\"" + filename + "\"",
      },
      Header::{
        name: "Content-Transfer-Encoding",
        value: "base64",
      },
    ],
    body: Body::Binary(body),
  }
}


/// A structured RFC 5322 date-time value.
/// Represents the components of a date header after parsing.
pub struct EmailDate {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
  tz_hour : Int
  tz_minute : Int
  tz_sign : Int
}

/// A parsed Message-ID header value: <id@domain>
pub struct MessageId {
  id : String
  domain : String
}

/// A structured Received header value.
/// Received: from a by b with c for d; date
pub struct ReceivedInfo {
  from_ : String
  by : String
  with_ : String
  for_ : String
  date : String
}

/// An address group: GroupName: member1, member2;
pub struct AddressGroup {
  name : String
  members : Array[EmailAddress]
}

/// Create an EmailDate value from its components.
pub fn email_date(
  year~ : Int,
  month~ : Int,
  day~ : Int,
  hour~ : Int = 0,
  minute~ : Int = 0,
  second~ : Int = 0,
  tz_hour~ : Int = 0,
  tz_minute~ : Int = 0,
  tz_sign~ : Int = 1,
) -> EmailDate {
  EmailDate::{ year, month, day, hour, minute, second, tz_hour, tz_minute, tz_sign }
}

/// Create a MessageId value.
pub fn message_id(id~ : String, domain~ : String) -> MessageId {
  MessageId::{ id, domain }
}

/// Create a ReceivedInfo value.
pub fn received_info(
  from_~ : String = "",
  by~ : String = "",
  with_~ : String = "",
  for_~ : String = "",
  date~ : String = "",
) -> ReceivedInfo {
  ReceivedInfo::{ from_, by, with_, for_, date }
}

/// Create an AddressGroup value.
pub fn address_group(name~ : String, members~ : Array[EmailAddress]) -> AddressGroup {
  AddressGroup::{ name, members }
}

/// Format an EmailDate as an RFC 5322 date-time string.
/// Output format: "Mon, 01 Jan 2026 12:34:56 +0800"
pub fn email_date_to_string(d : EmailDate) -> String {
  let month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  let day_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  let month_name = month_names[d.month - 1]
  let day_name = day_names[weekday(d)]
  let sign = if d.tz_sign >= 0 { "+" } else { "-" }
  let tz_h = two_digits(d.tz_hour)
  let tz_m = two_digits(d.tz_minute)
  day_name + ", " + two_digits(d.day) + " " + month_name + " " +
    d.year.to_string() + " " + two_digits(d.hour) + ":" +
    two_digits(d.minute) + ":" + two_digits(d.second) + " " +
    sign + tz_h + tz_m
}

/// Compute the day of the week (0 = Sunday) using Zeller's congruence.
fn weekday(d : EmailDate) -> Int {
  let mut year = d.year
  let mut month = d.month
  if month < 3 {
    month = month + 12
    year = year - 1
  }
  let k = year % 100
  let j = year / 100
  let h = (d.day + (13 * (month + 1)) / 5 + k + (k / 4) + (j / 4) + (5 * j)) % 7
  (h + 5) % 7
}

/// Pad a number to two digits: 5 -> "05"
fn two_digits(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

/// Format a MessageId as an RFC 5322 Message-ID header value.
pub fn message_id_to_string(mid : MessageId) -> String {
  "<" + mid.id + "@" + mid.domain + ">"
}

/// Parse a Message-ID header value into a MessageId.
/// Accepts "<id@domain>" with optional surrounding whitespace.
pub fn parse_message_id(input : String) -> MessageId? {
  let s = input.trim(chars=" \t\r\n").to_owned()
  let content = if s.has_prefix("<") && s.has_suffix(">") {
    s.unsafe_substring(start=1, end=s.length() - 1)
  } else {
    s
  }
  let at_pos = content.find("@")
  match at_pos {
    None => None
    Some(pos) => {
      let id = content.unsafe_substring(start=0, end=pos)
      let domain = content.unsafe_substring(start=pos + 1, end=content.length())
      if id.length() > 0 && domain.length() > 0 {
        Some(MessageId::{ id, domain })
      } else {
        None
      }
    }
  }
}

/// Check whether a ContentType is a multipart type.
pub fn is_multipart(ct : ContentType) -> Bool {
  ct.media_type == "multipart"
}

/// Check whether a ContentType is a text type.
pub fn is_text(ct : ContentType) -> Bool {
  ct.media_type == "text"
}

/// Check whether a ContentType is an image type.
pub fn is_image(ct : ContentType) -> Bool {
  ct.media_type == "image"
}

/// Check whether a ContentType is an application type.
pub fn is_application(ct : ContentType) -> Bool {
  ct.media_type == "application"
}

/// Look up a parameter value by name in a ContentType.
pub fn content_type_param(ct : ContentType, name : String) -> String? {
  let lower = name.to_lower()
  for i = 0; i < ct.params.length(); i = i + 1 {
    let (k, v) = ct.params[i]
    if k == lower {
      return Some(v)
    }
  }
  None
}

/// Look up a parameter value by name in a ContentDisposition.
pub fn disposition_param(cd : ContentDisposition, name : String) -> String? {
  let lower = name.to_lower()
  for i = 0; i < cd.params.length(); i = i + 1 {
    let (k, v) = cd.params[i]
    if k == lower {
      return Some(v)
    }
  }
  None
}

/// Check whether a message has a header with the given name (case-insensitive).
pub fn has_header(msg : Message, name : String) -> Bool {
  let lower = name.to_lower()
  for h in msg.headers {
    if h.name.to_lower() == lower {
      return true
    }
  }
  false
}

/// Get all header values with a name, as a single array.
pub fn all_headers(msg : Message, name : String) -> Array[Header] {
  let lower = name.to_lower()
  let results : Array[Header] = []
  for h in msg.headers {
    if h.name.to_lower() == lower {
      results.push(h)
    }
  }
  results
}

/// Get the Content-Type of a message as a parsed ContentType.
pub fn message_content_type(msg : Message) -> ContentType? {
  let value = get_header(msg, "Content-Type")
  match value {
    None => None
    Some(v) => parse_content_type(v)
  }
}

/// Get the boundary parameter of a multipart message.
pub fn message_boundary(msg : Message) -> String? {
  let ct = message_content_type(msg)
  match ct {
    None => None
    Some(c) => content_type_param(c, "boundary")
  }
}

/// Format an EmailDate to a compact ISO-like string (for diagnostics).
pub fn email_date_to_iso(d : EmailDate) -> String {
  d.year.to_string() + "-" + two_digits(d.month) + "-" + two_digits(d.day) +
    "T" + two_digits(d.hour) + ":" + two_digits(d.minute) + ":" + two_digits(d.second)
}
