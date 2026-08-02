/// RFC 5322 address grammar parsing.
///
/// Extends the basic address parsing with the full mailbox syntax:
///   - Display names (phrases) before the angle-addr
///   - Comments in parentheses
///   - Group syntax:  GroupName: a@b, c@d;
///   - Domain and local-part validation
///
/// The parsed structures reuse the core AST types and add the
/// Mailbox type for display-name aware addresses.

/// A mailbox: optional display name plus the addr-spec.
pub struct Mailbox {
  display_name : String
  address : EmailAddress?
}

/// Create a Mailbox value.
pub fn mailbox(display_name~ : String = "", address~ : EmailAddress?) -> Mailbox {
  Mailbox::{ display_name, address }
}

/// Parse a full mailbox into a Mailbox value.
///
/// Handles formats:
///   user@example.com
///   <user@example.com>
///   Display Name <user@example.com>
///   "Display Name" <user@example.com>
///   Display Name (comment) <user@example.com>
pub fn parse_mailbox(input : String) -> Mailbox? {
  let s = input.trim(chars=" \t\r\n").to_owned()
  if s.length() == 0 {
    return None
  }

  // Find the angle-addr portion if present
  let langle = s.find("<")
  let rangle = s.find(">")

  if langle is Some(lp) && rangle is Some(rp) && rp > lp {
    // Extract the display name (text before <)
    let name_raw = s.unsafe_substring(start=0, end=lp).trim(chars=" \t\r\n").to_owned()
    let addr_str = s.unsafe_substring(start=lp + 1, end=rp)
    let addr = parse_address(addr_str)
    let display = clean_display_name(name_raw)
    let display_decoded = decode_header_value(display)
    Some(Mailbox::{
      display_name: display_decoded,
      address: addr,
    })
  } else {
    // No angle brackets: the whole thing is an addr-spec,
    // possibly with a leading phrase and comments.
    let stripped = strip_comments(s)
    let addr = parse_address(stripped)
    match addr {
      Some(a) => Some(Mailbox::{ display_name: "", address: Some(a) })
      None => {
        // Maybe "Display Name user@example.com" without brackets:
        // take the last token as the address
        parse_addr_from_phrase(stripped)
      }
    }
  }
}

/// Try to parse a phrase-form address without angle brackets.
/// Splits on the last '@' to find a plausible addr-spec tail.
fn parse_addr_from_phrase(s : String) -> Mailbox? {
  // Find the last whitespace before '@'
  let at_pos = s.find("@")
  match at_pos {
    None => None
    Some(ap) => {
      // Take the substring from the last space before @ to the end
      let mut last_space : Int = -1
      let mut i = 0
      while i < ap {
        let c = s.get_char(i).unwrap()
        if c == ' ' || c == '\t' {
          last_space = i
        }
        i = i + 1
      }
      if last_space >= 0 {
        let name = s.unsafe_substring(start=0, end=last_space).trim(chars=" \t").to_owned()
        let addr_str = s.unsafe_substring(start=last_space + 1, end=s.length())
        let addr = parse_address(addr_str)
        match addr {
          Some(a) => {
            Some(Mailbox::{
              display_name: decode_header_value(clean_display_name(name)),
              address: Some(a),
            })
          }
          None => None
        }
      } else {
        let addr = parse_address(s)
        match addr {
          Some(a) => Some(Mailbox::{ display_name: "", address: Some(a) })
          None => None
        }
      }
    }
  }
}

/// Clean a display name: strip quotes, unescape, and trim.
fn clean_display_name(s : String) -> String {
  let trimmed = s.trim(chars=" \t").to_owned()
  if trimmed.has_prefix("\"") && trimmed.has_suffix("\"") && trimmed.length() >= 2 {
    let inner = trimmed.unsafe_substring(start=1, end=trimmed.length() - 1)
    unescape_quoted(inner)
  } else {
    trimmed
  }
}

/// Remove backslash escapes from a quoted string.
fn unescape_quoted(s : String) -> String {
  let sb = StringBuilder::new()
  let len = s.length()
  let mut i = 0
  while i < len {
    let c = s.get_char(i).unwrap()
    if c == '\\' && i + 1 < len {
      sb.write_char(s.get_char(i + 1).unwrap())
      i = i + 2
    } else {
      sb.write_char(c)
      i = i + 1
    }
  }
  sb.to_string()
}

/// Parse an address list that may contain groups.
///
/// Returns all mailbox addresses found. Group members are flattened
/// into the result list.
pub fn parse_mailbox_list(input : String) -> Array[Mailbox] {
  let results : Array[Mailbox] = []
  let s = input.trim(chars=" \t\r\n").to_owned()
  if s.length() == 0 {
    return results
  }

  // Check for group syntax: ends with ';' and contains ':'
  if s.has_suffix(";") && s.contains(":") {
    // Split into groups
    let groups = split_groups(s)
    for g in groups {
      let members = parse_group_members(g)
      for m in members {
        results.push(m)
      }
    }
  } else {
    // Plain mailbox list
    let parts = split_addr_list(s)
    for part in parts {
      let mb = parse_mailbox(part)
      match mb {
        Some(m) => results.push(m)
        None => ()
      }
    }
  }

  results
}

/// Split an address list into group segments.
fn split_groups(input : String) -> Array[String] {
  let results : Array[String] = []
  let len = input.length()
  let mut start = 0
  let mut in_quote = false
  let mut i = 0
  while i < len {
    let c = input.get_char(i).unwrap()
    if c == '"' {
      in_quote = !in_quote
    } else if c == ';' && !in_quote {
      let segment = input.unsafe_substring(start=start, end=i + 1)
      results.push(segment)
      start = i + 1
    }
    i = i + 1
  }
  if start < len {
    results.push(input.unsafe_substring(start=start, end=len))
  }
  results
}

/// Parse the members of a single group: "Name: a@b, c@d;"
fn parse_group_members(group : String) -> Array[Mailbox] {
  let results : Array[Mailbox] = []
  let colon = group.find(":")
  match colon {
    None => {
      // Not a group, treat as mailbox
      let mb = parse_mailbox(group)
      match mb {
        Some(m) => results.push(m)
        None => ()
      }
    }
    Some(cp) => {
      let member_part = group.unsafe_substring(start=cp + 1, end=group.length()).trim(chars=" \t;").to_owned()
      let parts = split_addr_list(member_part)
      for part in parts {
        let mb = parse_mailbox(part)
        match mb {
          Some(m) => results.push(m)
          None => ()
        }
      }
    }
  }
  results
}

/// Validate a domain per RFC 5322: letters, digits, hyphen, and dots.
pub fn validate_domain(domain : String) -> Bool {
  if domain.length() == 0 {
    return false
  }
  let mut last_was_dot = true // leading dot not allowed
  let mut i = 0
  while i < domain.length() {
    let c = domain.get_char(i).unwrap()
    if c == '.' {
      if last_was_dot {
        return false
      }
      last_was_dot = true
    } else if is_domain_char(c) {
      last_was_dot = false
    } else {
      return false
    }
    i = i + 1
  }
  !last_was_dot
}

/// Check whether a character is valid in a domain label.
fn is_domain_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') || c == '-'
}

/// Validate a local part per RFC 5322.
/// Accepts dot-atom and quoted-string forms.
pub fn validate_local_part(local_part : String) -> Bool {
  if local_part.length() == 0 {
    return false
  }
  if local_part.has_prefix("\"") {
    // Quoted form: must end with a quote
    local_part.has_suffix("\"") && local_part.length() >= 2
  } else {
    // Dot-atom: atext separated by dots, no leading/trailing/consecutive dots
    let mut last_was_dot = true
    let mut i = 0
    while i < local_part.length() {
      let c = local_part.get_char(i).unwrap()
      if c == '.' {
        if last_was_dot {
          return false
        }
        last_was_dot = true
      } else if is_atext_char(c) {
        last_was_dot = false
      } else {
        return false
      }
      i = i + 1
    }
    !last_was_dot
  }
}

/// Check whether a character is valid in an atom (RFC 5322 atext).
fn is_atext_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '!' || c == '#' || c == '$' || c == '%' || c == '&' ||
  c == '\'' || c == '*' || c == '+' || c == '-' || c == '/' ||
  c == '=' || c == '?' || c == '^' || c == '_' || c == '`' ||
  c == '{' || c == '|' || c == '}' || c == '~'
}

/// Validate a full email address (local part and domain).
pub fn validate_email_address(addr : EmailAddress) -> Bool {
  validate_local_part(addr.local_part) && validate_domain(addr.domain)
}

/// Get the display name from a Mailbox, or the local part if empty.
pub fn mailbox_display_name(mb : Mailbox) -> String {
  if mb.display_name.length() > 0 {
    mb.display_name
  } else {
    match mb.address {
      None => ""
      Some(a) => a.local_part
    }
  }
}

/// Format a Mailbox back to a string.
pub fn mailbox_to_string(mb : Mailbox) -> String {
  let addr_str = match mb.address {
    None => ""
    Some(a) => address_to_string(a)
  }
  if mb.display_name.length() > 0 {
    // Quote the display name if it contains special characters
    let name = if mb.display_name.contains(",") || mb.display_name.contains(";") ||
                 mb.display_name.contains(":") || mb.display_name.contains("<") ||
                 mb.display_name.contains(">") || mb.display_name.contains("@") {
      "\"" + mb.display_name + "\""
    } else {
      mb.display_name
    }
    if addr_str.length() > 0 {
      name + " <" + addr_str + ">"
    } else {
      name
    }
  } else {
    addr_str
  }
}

/// Convert a list of Mailboxes to a comma-separated string.
pub fn mailbox_list_to_string(mbs : Array[Mailbox]) -> String {
  let sb = StringBuilder::new()
  for i = 0; i < mbs.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(", ")
    }
    sb.write_string(mailbox_to_string(mbs[i]))
  }
  sb.to_string()
}

/// Get all EmailAddress values from an array of Mailboxes.
pub fn mailbox_addresses(mbs : Array[Mailbox]) -> Array[EmailAddress] {
  let results : Array[EmailAddress] = []
  for mb in mbs {
    match mb.address {
      Some(a) => results.push(a)
      None => ()
    }
  }
  results
}
