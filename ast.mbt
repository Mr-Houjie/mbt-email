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
