/// Message-level header analysis.
///
/// Provides high-level helpers for working with parsed Message values:
///   - Message-ID, References, and In-Reply-To handling
///   - Received header chain analysis
///   - Structured access to From/To/Cc/Subject headers
///   - Subject decoding (RFC 2047)

///|
/// Parse a Message-ID or a space-separated list of Message-IDs.
/// Handles both "<a@b>" and "<a@b> <c@d>" formats.
pub fn parse_message_ids(input : String) -> Array[MessageId] {
  let results : Array[MessageId] = []
  let s = input.trim(chars=" \t\r\n").to_owned()
  if s.length() == 0 {
    return results
  }
  // Find all <...> tokens by scanning for each '<' and its matching '>'
  let len = s.length()
  let mut i = 0
  while i < len {
    if s.get_char(i).unwrap() == '<' {
      // Find the closing '>' after this position
      let mut j = i + 1
      while j < len && s.get_char(j).unwrap() != '>' {
        j = j + 1
      }
      if j < len {
        let id_str = s.unsafe_substring(start=i, end=j + 1)
        let mid = parse_message_id(id_str)
        match mid {
          Some(m) => results.push(m)
          None => ()
        }
        i = j + 1
        continue
      }
    }
    i = i + 1
  }
  results
}

///|
/// Parse a Received header value into structured ReceivedInfo.
///
/// Format: from a by b with c for d; date
/// Each clause is optional; date follows the ';'.
pub fn parse_received_header(value : String) -> ReceivedInfo {
  let s = value.trim(chars=" \t\r\n").to_owned()
  let mut from_str = ""
  let mut by_str = ""
  let mut with_str = ""
  let mut for_str = ""
  let mut date_str = ""

  // Split at the first ';' to separate clauses from the date
  let semi = s.find(";")
  let (clause_part, date_part) = match semi {
    None => (s, "")
    Some(sp) =>
      (
        s.unsafe_substring(start=0, end=sp),
        s
        .unsafe_substring(start=sp + 1, end=s.length())
        .trim(chars=" \t")
        .to_owned(),
      )
  }

  // Parse the date portion
  let date_parsed = parse_email_date(date_part)
  match date_parsed {
    None => ()
    Some(d) => date_str = email_date_to_string(d)
  }

  // Tokenize the clause part and extract known keywords
  let tokens = split_ws(clause_part)
  let mut i = 0
  while i < tokens.length() {
    let t = tokens[i]
    if t == "from" && i + 1 < tokens.length() {
      from_str = tokens[i + 1]
      i = i + 2
    } else if t == "by" && i + 1 < tokens.length() {
      by_str = tokens[i + 1]
      i = i + 2
    } else if t == "with" && i + 1 < tokens.length() {
      with_str = tokens[i + 1]
      i = i + 2
    } else if t == "for" && i + 1 < tokens.length() {
      for_str = tokens[i + 1]
      i = i + 2
    } else {
      i = i + 1
    }
  }

  received_info(
    from_=from_str,
    by=by_str,
    with_=with_str,
    for_=for_str,
    date=date_str,
  )
}

///|
/// Split a string on whitespace into tokens.
fn split_ws(input : String) -> Array[String] {
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
/// Get the parsed From addresses of a message as Mailboxes.
pub fn message_from_mailboxes(msg : Message) -> Array[Mailbox] {
  let value = get_header(msg, "From")
  match value {
    None => []
    Some(v) => parse_mailbox_list(v)
  }
}

///|
/// Get the parsed To addresses of a message as Mailboxes.
pub fn message_to_mailboxes(msg : Message) -> Array[Mailbox] {
  let value = get_header(msg, "To")
  match value {
    None => []
    Some(v) => parse_mailbox_list(v)
  }
}

///|
/// Get the parsed Cc addresses of a message as Mailboxes.
pub fn message_cc_mailboxes(msg : Message) -> Array[Mailbox] {
  let value = get_header(msg, "Cc")
  match value {
    None => []
    Some(v) => parse_mailbox_list(v)
  }
}

///|
/// Get the decoded Subject of a message.
/// RFC 2047 encoded-words are decoded to plain text.
pub fn message_subject(msg : Message) -> String {
  let value = get_header(msg, "Subject")
  match value {
    None => ""
    Some(v) => decode_header_value(v)
  }
}

///|
/// Get the Message-ID of a message, if present.
pub fn message_message_id(msg : Message) -> MessageId? {
  let value = get_header(msg, "Message-ID")
  match value {
    None => None
    Some(v) => parse_message_id(v)
  }
}

///|
/// Get the References header of a message as a list of MessageIds.
pub fn message_references(msg : Message) -> Array[MessageId] {
  let value = get_header(msg, "References")
  match value {
    None => []
    Some(v) => parse_message_ids(v)
  }
}

///|
/// Get the In-Reply-To header of a message as a list of MessageIds.
pub fn message_in_reply_to(msg : Message) -> Array[MessageId] {
  let value = get_header(msg, "In-Reply-To")
  match value {
    None => []
    Some(v) => parse_message_ids(v)
  }
}

///|
/// Get the Received chain of a message (topmost first).
pub fn message_received_chain(msg : Message) -> Array[ReceivedInfo] {
  let results : Array[ReceivedInfo] = []
  let values = get_headers(msg, "Received")
  // Received headers are listed newest first; reverse for chronological order
  let mut i = values.length() - 1
  while i >= 0 {
    let info = parse_received_header(values[i])
    results.push(info)
    i = i - 1
  }
  results
}

///|
/// Get the Reply-To addresses of a message, falling back to From.
pub fn message_reply_to(msg : Message) -> Array[Mailbox] {
  let rt = get_header(msg, "Reply-To")
  match rt {
    Some(v) => parse_mailbox_list(v)
    None => message_from_mailboxes(msg)
  }
}

///|
/// Check whether the message is a reply (has In-Reply-To or References).
pub fn is_reply(msg : Message) -> Bool {
  has_header(msg, "In-Reply-To") || has_header(msg, "References")
}

///|
/// Check whether the message is a bounce/undeliverable notice.
pub fn is_bounce(msg : Message) -> Bool {
  has_header(msg, "Return-Path") ||
  has_header(msg, "X-Failed-Recipients") ||
  has_header(msg, "Diagnostic-Code")
}

///|
/// Get the Return-Path address, if present.
pub fn message_return_path(msg : Message) -> EmailAddress? {
  let value = get_header(msg, "Return-Path")
  match value {
    None => None
    Some(v) => {
      let s = v.trim(chars=" \t\r\n").to_owned()
      if s == "<>" {
        None
      } else {
        parse_address(s)
      }
    }
  }
}

///|
/// Get the Content-Type of a message as a decoded ContentType.
/// RFC 2231 extended parameters are merged.
pub fn message_decoded_content_type(msg : Message) -> ContentType? {
  let value = get_header(msg, "Content-Type")
  match value {
    None => None
    Some(v) => decode_content_type(v)
  }
}

///|
/// Get the Content-Disposition of a message as a decoded ContentDisposition.
pub fn message_decoded_disposition(msg : Message) -> ContentDisposition? {
  let value = get_header(msg, "Content-Disposition")
  match value {
    None => None
    Some(v) => decode_content_disposition(v)
  }
}

///|
/// Extract all email addresses from the From, To, Cc, and Bcc headers.
pub fn message_all_addresses(msg : Message) -> Array[Mailbox] {
  let results : Array[Mailbox] = []
  let from = message_from_mailboxes(msg)
  for mb in from {
    results.push(mb)
  }
  let to = message_to_mailboxes(msg)
  for mb in to {
    results.push(mb)
  }
  let cc = message_cc_mailboxes(msg)
  for mb in cc {
    results.push(mb)
  }
  let bcc = get_header(msg, "Bcc")
  match bcc {
    None => ()
    Some(v) => {
      let b = parse_mailbox_list(v)
      for mb in b {
        results.push(mb)
      }
    }
  }
  results
}

///|
/// Get the sender address (Sender header or From).
pub fn message_sender(msg : Message) -> Array[Mailbox] {
  let value = get_header(msg, "Sender")
  match value {
    Some(v) => parse_mailbox_list(v)
    None => message_from_mailboxes(msg)
  }
}

///|
/// Generate a unique Message-ID for a new message.
/// Format: <prefix.timestamp@domain>
/// The timestamp is derived from a caller-provided value so the function
/// stays pure and deterministic for testing.
pub fn generate_message_id(domain : String, timestamp? : Int = 0) -> MessageId {
  let ts = timestamp
  let rand = ts * 7919 + 104729
  let id = "mbt." + ts.to_string() + "." + rand.to_string()
  message_id(id~, domain~)
}

///|
/// Get the List-Unsubscribe header, if present.
pub fn message_list_unsubscribe(msg : Message) -> String? {
  get_header(msg, "List-Unsubscribe")
}

///|
/// Check whether a message has a priority header.
pub fn message_priority(msg : Message) -> String? {
  let pri = get_header(msg, "X-Priority")
  match pri {
    Some(p) => Some(p)
    None => get_header(msg, "Priority")
  }
}

///|
/// Get the number of headers in a message.
pub fn message_header_count(msg : Message) -> Int {
  msg.headers.length()
}

///|
/// Summarize a message: Subject, From, and Date in one string.
pub fn summarize_message(msg : Message) -> String {
  let subject = message_subject(msg)
  let from = match message_from_mailboxes(msg) {
    [] => "(unknown)"
    mbs => mailbox_list_to_string(mbs)
  }
  let date = match message_date(msg) {
    None => "(no date)"
    Some(d) => email_date_to_iso(d)
  }
  "From: " + from + " | Subject: " + subject + " | Date: " + date
}
