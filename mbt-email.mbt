/// mbt-email: An RFC 5322/2045 email address and MIME message parser for MoonBit.
///
/// This package provides a complete email parsing pipeline:
///   parse() - Parse raw email text into a Message AST
///   parse_address() - Parse a single email address
///   parse_address_list() - Parse multiple email addresses from a header value
///   parse_content_type() - Parse MIME Content-Type header values
///   parse_content_disposition() - Parse MIME Content-Disposition values
///   decode_encoded_word() - Decode RFC 2047 encoded-words (=?UTF-8?B?...?=)
///   to_string() - Serialize a Message back to RFC 5322 text
///
/// Supported features:
///   - RFC 5322 message headers (From, To, Cc, Subject, Date, etc.)
///   - RFC 5322 email address parsing (dot-atom, quoted-string, domain-literal)
///   - RFC 2045/2046 MIME multipart message parsing
///   - RFC 2047 encoded-word decoding (Base64 and Quoted-Printable)
///   - Content-Type and Content-Disposition parameter parsing
///   - Round-trip parse → serialize

///|
/// Parse a raw email string into a Message AST.
pub fn parse(input : String) -> Message {
  parse_message(input)
}

///|
/// Parse a MIME message with full multipart support.
pub fn parse_mime(input : String) -> Message {
  parse_mime_message(input)
}

///|
/// Serialize a Message back to RFC 5322 format text.
pub fn to_string(msg : Message) -> String {
  message_to_string(msg)
}
