/// Black-box tests for the extended mbt-email features:
/// date parsing, encoded-words, RFC 2231, MIME, addresses, codecs.

///|
/// Parse a full RFC 5322 date with timezone
test "parse_date_full" {
  let d = @Mr-Houjie/mbt-email.parse_email_date("Mon, 01 Jan 2026 12:34:56 +0800")
  match d {
    Some(v) => {
      assert_eq(v.year, 2026)
      assert_eq(v.month, 1)
      assert_eq(v.day, 1)
      assert_eq(v.hour, 12)
      assert_eq(v.minute, 34)
      assert_eq(v.second, 56)
      assert_eq(v.tz_hour, 8)
      assert_eq(v.tz_minute, 0)
      assert_eq(v.tz_sign, 1)
    }
    None => assert_true(false)
  }
}

///|
/// Parse a date without weekday and with GMT zone
test "parse_date_no_weekday" {
  let d = @Mr-Houjie/mbt-email.parse_email_date("1 Jan 2026 12:34:56 GMT")
  match d {
    Some(v) => {
      assert_eq(v.year, 2026)
      assert_eq(v.month, 1)
      assert_eq(v.day, 1)
      assert_eq(v.tz_hour, 0)
      assert_eq(v.tz_sign, 1)
    }
    None => assert_true(false)
  }
}

///|
/// Parse a date with negative timezone
test "parse_date_negative_tz" {
  let d = @Mr-Houjie/mbt-email.parse_email_date("Tue, 2 Feb 2026 08:00:00 -0500")
  match d {
    Some(v) => {
      assert_eq(v.tz_hour, 5)
      assert_eq(v.tz_sign, -1)
    }
    None => assert_true(false)
  }
}

///|
/// Parse an invalid date returns None
test "parse_date_invalid" {
  let d = @Mr-Houjie/mbt-email.parse_email_date("not a date")
  assert_true(d is None)
}

///|
/// Format an EmailDate back to RFC 5322
test "format_date_roundtrip" {
  let d = @Mr-Houjie/mbt-email.parse_email_date("Thu, 01 Jan 2026 12:34:56 +0800")
  match d {
    Some(v) => {
      let s = @Mr-Houjie/mbt-email.email_date_to_string(v)
      assert_eq(s, "Thu, 01 Jan 2026 12:34:56 +0800")
    }
    None => assert_true(false)
  }
}

///|
/// Leap year detection
test "leap_year" {
  assert_true(@Mr-Houjie/mbt-email.is_leap_year(2024))
  assert_true(@Mr-Houjie/mbt-email.is_leap_year(2000))
  assert_true(!@Mr-Houjie/mbt-email.is_leap_year(2026))
  assert_true(!@Mr-Houjie/mbt-email.is_leap_year(1900))
}

///|
/// Days in month including February
test "days_in_month" {
  assert_eq(@Mr-Houjie/mbt-email.days_in_month(2026, 1), 31)
  assert_eq(@Mr-Houjie/mbt-email.days_in_month(2026, 2), 28)
  assert_eq(@Mr-Houjie/mbt-email.days_in_month(2024, 2), 29)
  assert_eq(@Mr-Houjie/mbt-email.days_in_month(2026, 4), 30)
}

///|
/// Timestamp conversion
test "timestamp_conversion" {
  let d = @Mr-Houjie/mbt-email.parse_email_date("Thu, 01 Jan 1970 00:00:00 +0000")
  match d {
    Some(v) => assert_eq(@Mr-Houjie/mbt-email.to_timestamp(v), 0)
    None => assert_true(false)
  }
}

///|
/// Compare two dates
test "compare_dates" {
  let a = @Mr-Houjie/mbt-email.parse_email_date("Thu, 01 Jan 2026 00:00:00 +0000")
  let b = @Mr-Houjie/mbt-email.parse_email_date("Fri, 02 Jan 2026 00:00:00 +0000")
  match (a, b) {
    (Some(x), Some(y)) => {
      assert_eq(@Mr-Houjie/mbt-email.compare_dates(x, y), -1)
      assert_eq(@Mr-Houjie/mbt-email.compare_dates(y, x), 1)
      assert_eq(@Mr-Houjie/mbt-email.compare_dates(x, x), 0)
    }
    _ => assert_true(false)
  }
}

///|
/// Decode a header value with multiple encoded-words
test "decode_header_value_multiple" {
  let decoded = @Mr-Houjie/mbt-email.decode_header_value(
    "=?UTF-8?B?SGVsbG8=?= =?UTF-8?B?V29ybGQ=?=",
  )
  assert_eq(decoded, "HelloWorld")
}

///|
/// Decode encoded-word in mixed text
test "decode_header_value_mixed" {
  let decoded = @Mr-Houjie/mbt-email.decode_header_value(
    "Hello =?UTF-8?B?V29ybGQ=?= !",
  )
  assert_eq(decoded, "Hello World !")
}

///|
/// Count encoded-words
test "count_encoded_words" {
  let n = @Mr-Houjie/mbt-email.count_encoded_words(
    "=?UTF-8?B?QQ==?= =?UTF-8?B?Qg==?=",
  )
  assert_eq(n, 2)
}

///|
/// RFC 2231 single-part extended parameter
test "decode_rfc2231_single" {
  let decoded = @Mr-Houjie/mbt-email.decode_rfc2231_value(
    "UTF-8''hello%20world.txt",
  )
  match decoded {
    Some(s) => assert_eq(s, "hello world.txt")
    None => assert_true(false)
  }
}

///|
/// RFC 2231 percent decode
test "percent_decode" {
  let decoded = @Mr-Houjie/mbt-email.percent_decode("%E4%B8%AD%E6%96%87")
  match decoded {
    Some(s) => assert_eq(s, "中文")
    None => assert_true(false)
  }
}

///|
/// Merge RFC 2231 continuation segments
test "merge_continuations" {
  let params : Array[(String, String)] = [
    ("filename*0*", "UTF-8''%E4%B8%AD"),
    ("filename*1*", "%E6%96%87.txt"),
  ]
  let merged = @Mr-Houjie/mbt-email.merge_extended_params(params)
  assert_eq(merged.length(), 1)
  assert_eq(merged[0].0, "filename")
}

///|
/// Strip comments from a header value
test "strip_comments" {
  let s = @Mr-Houjie/mbt-email.strip_comments("user (comment) @example.com")
  assert_eq(s, "user @example.com")
}

///|
/// Base64 encode with 76-column wrapping
test "b64_encode_wrap" {
  let data : Array[Int] = []
  let mut i = 0
  while i < 100 {
    data.push(i)
    i = i + 1
  }
  let encoded = @Mr-Houjie/mbt-email.b64_encode_bytes(data)
  assert_true(encoded.contains("\r\n"))
}

///|
/// Base64 decode bytes
test "b64_decode_bytes" {
  let decoded = @Mr-Houjie/mbt-email.b64_decode_text("SGVsbG8=")
  match decoded {
    Some(s) => assert_eq(s, "Hello")
    None => assert_true(false)
  }
}

///|
/// Base64 decode invalid input
test "b64_decode_invalid" {
  let decoded = @Mr-Houjie/mbt-email.b64_decode_text("###")
  assert_true(decoded is None)
}

///|
/// Quoted-printable encode and decode
test "qp_roundtrip" {
  let encoded = @Mr-Houjie/mbt-email.qp_encode_text("Hello, world!")
  match @Mr-Houjie/mbt-email.qp_decode(encoded) {
    Some(s) => assert_eq(s, "Hello, world!")
    None => assert_true(false)
  }
}

///|
/// Quoted-printable soft line breaks
test "qp_decode_soft_break" {
  let decoded = @Mr-Houjie/mbt-email.qp_decode("Hello =\r\nworld")
  match decoded {
    Some(s) => assert_eq(s, "Hello world")
    None => assert_true(false)
  }
}

///|
/// Quoted-printable hex escape
test "qp_decode_hex" {
  let decoded = @Mr-Houjie/mbt-email.qp_decode("a=3Db")
  match decoded {
    Some(s) => assert_eq(s, "a=b")
    None => assert_true(false)
  }
}

///|
/// ASCII detection
test "is_ascii_only" {
  assert_true(@Mr-Houjie/mbt-email.is_ascii_only("hello"))
  assert_true(!@Mr-Houjie/mbt-email.is_ascii_only("你好"))
}

///|
/// Encode a non-ASCII value as encoded-word
test "encode_encoded_word" {
  let encoded = @Mr-Houjie/mbt-email.encode_encoded_word_b("中文")
  assert_true(encoded.has_prefix("=?UTF-8?B?"))
  assert_true(encoded.has_suffix("?="))
}

///|
/// Parse a mailbox with display name
test "parse_mailbox_display_name" {
  let mb = @Mr-Houjie/mbt-email.parse_mailbox("Alice <alice@example.com>")
  match mb {
    Some(m) => {
      assert_eq(m.display_name, "Alice")
      match m.address {
        Some(a) => assert_eq(a.local_part, "alice")
        None => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
/// Parse a quoted display name
test "parse_mailbox_quoted_name" {
  let mb = @Mr-Houjie/mbt-email.parse_mailbox(
    "\"Alice Smith\" <alice@example.com>",
  )
  match mb {
    Some(m) => {
      assert_eq(m.display_name, "Alice Smith")
      match m.address {
        Some(a) => assert_eq(a.domain, "example.com")
        None => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
/// Validate a domain
test "validate_domain" {
  assert_true(@Mr-Houjie/mbt-email.validate_domain("example.com"))
  assert_true(@Mr-Houjie/mbt-email.validate_domain("mail.example.com"))
  assert_true(!@Mr-Houjie/mbt-email.validate_domain(".example.com"))
  assert_true(!@Mr-Houjie/mbt-email.validate_domain("exa mple.com"))
}

///|
/// Validate a local part
test "validate_local_part" {
  assert_true(@Mr-Houjie/mbt-email.validate_local_part("user.name"))
  assert_true(@Mr-Houjie/mbt-email.validate_local_part("user"))
  assert_true(!@Mr-Houjie/mbt-email.validate_local_part(".user"))
  assert_true(!@Mr-Houjie/mbt-email.validate_local_part("user..name"))
}

///|
/// Format a mailbox back to a string
test "mailbox_to_string" {
  let mb = @Mr-Houjie/mbt-email.mailbox(
    display_name="Alice",
    address=Some(
      @Mr-Houjie/mbt-email.email_address(local_part="alice", domain="example.com"),
    ),
  )
  let s = @Mr-Houjie/mbt-email.mailbox_to_string(mb)
  assert_eq(s, "Alice <alice@example.com>")
}

///|
/// Parse Message-ID list
test "parse_message_ids" {
  let ids = @Mr-Houjie/mbt-email.parse_message_ids("<a@x.com> <b@y.com>")
  assert_eq(ids.length(), 2)
  assert_eq(ids[0].id, "a")
  assert_eq(ids[1].domain, "y.com")
}

///|
/// Parse Received header
test "parse_received" {
  let info = @Mr-Houjie/mbt-email.parse_received_header(
    "from mail.example.com by relay.example.com with ESMTP; Mon, 01 Jan 2026 12:00:00 +0000",
  )
  assert_eq(info.from_, "mail.example.com")
  assert_eq(info.by, "relay.example.com")
}

///|
/// Extract subject with encoded-word decoding
test "message_subject_decoded" {
  let input = "From: a@b.c\r\nSubject: =?UTF-8?B?SGVsbG8=?=\r\n\r\nHi\r\n"
  let msg = @Mr-Houjie/mbt-email.parse(input)
  assert_eq(@Mr-Houjie/mbt-email.message_subject(msg), "Hello")
}

///|
/// Extract From mailboxes
test "message_from_mailboxes" {
  let input = "From: Alice <alice@example.com>\r\n\r\nHi\r\n"
  let msg = @Mr-Houjie/mbt-email.parse(input)
  let mbs = @Mr-Houjie/mbt-email.message_from_mailboxes(msg)
  assert_eq(mbs.length(), 1)
  assert_eq(mbs[0].display_name, "Alice")
}

///|
/// Message-ID generation
test "generate_message_id" {
  let mid = @Mr-Houjie/mbt-email.generate_message_id("example.com", timestamp=1000)
  assert_eq(mid.domain, "example.com")
  assert_true(mid.id.has_prefix("mbt.1000."))
}

///|
/// HTML escaping
test "html_escape" {
  assert_eq(
    @Mr-Houjie/mbt-email.html_escape("<a>&\"'"),
    "&lt;a&gt;&amp;&quot;&#39;",
  )
}

///|
/// HTML to text
test "html_to_text" {
  let text = @Mr-Houjie/mbt-email.html_to_text("<p>Hello <b>World</b></p>")
  assert_eq(text, "Hello World")
}

///|
/// URL encoding
test "url_encode" {
  assert_eq(@Mr-Houjie/mbt-email.url_encode("a b"), "a%20b")
  assert_eq(@Mr-Houjie/mbt-email.url_encode("abc"), "abc")
}

///|
/// UTF-8 encode and decode roundtrip
test "utf8_roundtrip" {
  let bytes = @Mr-Houjie/mbt-email.utf8_encode("中文")
  let decoded = @Mr-Houjie/mbt-email.utf8_decode(bytes)
  assert_eq(decoded, "中文")
}

///|
/// IPv4 validation
test "is_ipv4" {
  assert_true(@Mr-Houjie/mbt-email.is_ipv4("127.0.0.1"))
  assert_true(!@Mr-Houjie/mbt-email.is_ipv4("999.0.0.1"))
  assert_true(!@Mr-Houjie/mbt-email.is_ipv4("1.2.3"))
}

///|
/// Header name validation
test "valid_header_name" {
  assert_true(@Mr-Houjie/mbt-email.valid_header_name("Content-Type"))
  assert_true(!@Mr-Houjie/mbt-email.valid_header_name("Content Type"))
  assert_true(!@Mr-Houjie/mbt-email.valid_header_name(""))
}

///|
/// Truncate helper
test "truncate" {
  assert_eq(@Mr-Houjie/mbt-email.truncate("hello world", 5), "he...")
  assert_eq(@Mr-Houjie/mbt-email.truncate("hi", 5), "hi")
}

///|
/// Simple hash is deterministic
test "simple_hash" {
  assert_eq(
    @Mr-Houjie/mbt-email.simple_hash("abc"),
    @Mr-Houjie/mbt-email.simple_hash("abc"),
  )
}

///|
/// MIME message with multipart body
test "parse_mime_multipart" {
  let input = "From: a@b.c\r\n" +
    "Content-Type: multipart/mixed; boundary=\"BND\"\r\n" +
    "\r\n" +
    "--BND\r\n" +
    "Content-Type: text/plain\r\n" +
    "\r\n" +
    "Hello\r\n" +
    "--BND\r\n" +
    "Content-Type: application/octet-stream\r\n" +
    "Content-Disposition: attachment; filename=doc.txt\r\n" +
    "\r\n" +
    "content\r\n" +
    "--BND--\r\n"
  let msg = @Mr-Houjie/mbt-email.parse_mime(input)
  match msg.mime_part {
    Some(part) =>
      match part.body {
        Body::Multipart(parts) => assert_eq(parts.length(), 2)
        _ => assert_true(false)
      }
    None => assert_true(false)
  }
}

///|
/// Detect attachments in a MIME message
test "detect_attachment" {
  let input = "From: a@b.c\r\n" +
    "Content-Type: multipart/mixed; boundary=\"BND\"\r\n" +
    "\r\n" +
    "--BND\r\n" +
    "Content-Type: text/plain\r\n" +
    "\r\n" +
    "Hello\r\n" +
    "--BND\r\n" +
    "Content-Type: application/pdf\r\n" +
    "Content-Disposition: attachment; filename=file.pdf\r\n" +
    "\r\n" +
    "PDFDATA\r\n" +
    "--BND--\r\n"
  let msg = @Mr-Houjie/mbt-email.parse_mime(input)
  match msg.mime_part {
    Some(part) => {
      let attachments = @Mr-Houjie/mbt-email.collect_attachments(part)
      assert_eq(attachments.length(), 1)
      let name = @Mr-Houjie/mbt-email.part_filename(attachments[0])
      match name {
        Some(n) => assert_eq(n, "file.pdf")
        None => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
/// Extract plain text from MIME tree
test "extract_plain_text" {
  let input = "From: a@b.c\r\n" +
    "Content-Type: multipart/alternative; boundary=\"BND\"\r\n" +
    "\r\n" +
    "--BND\r\n" +
    "Content-Type: text/plain\r\n" +
    "\r\n" +
    "plain body\r\n" +
    "--BND\r\n" +
    "Content-Type: text/html\r\n" +
    "\r\n" +
    "<p>html body</p>\r\n" +
    "--BND--\r\n"
  let msg = @Mr-Houjie/mbt-email.parse_mime(input)
  match msg.mime_part {
    Some(part) =>
      match @Mr-Houjie/mbt-email.plain_text(part) {
        Some(t) => assert_eq(t, "plain body")
        None => assert_true(false)
      }
    None => assert_true(false)
  }
}

///|
/// Build a text message and parse it back
test "build_text_message" {
  let msg = @Mr-Houjie/mbt-email.make_text_message(
    from="a@b.c",
    to="c@d.e",
    subject="Test",
    body="Hello!",
  )
  let text = @Mr-Houjie/mbt-email.to_string(msg)
  assert_true(text.contains("From: a@b.c"))
  assert_true(text.contains("Subject: Test"))
  assert_true(text.contains("Hello!"))
}

///|
/// Fold a long header value
test "fold_header_value" {
  let long_value = String::make(100, 'x')
  let folded = @Mr-Houjie/mbt-email.fold_header_value("Subject", long_value)
  assert_true(folded.contains("\r\n "))
  assert_true(folded.has_prefix("Subject: "))
}

///|
/// Content-Type to string roundtrip
test "content_type_to_string" {
  let ct = @Mr-Houjie/mbt-email.parse_content_type("text/plain; charset=utf-8")
  match ct {
    Some(c) => {
      let s = @Mr-Houjie/mbt-email.content_type_to_string(c)
      assert_true(s.has_prefix("text/plain"))
      assert_true(s.contains("charset=utf-8"))
    }
    None => assert_true(false)
  }
}

///|
/// Message summary
test "summarize_message" {
  let input = "From: a@b.c\r\nSubject: Hi\r\nDate: Mon, 01 Jan 2026 12:00:00 +0000\r\n\r\nbody\r\n"
  let msg = @Mr-Houjie/mbt-email.parse(input)
  let summary = @Mr-Houjie/mbt-email.summarize_message(msg)
  assert_true(summary.contains("Subject: Hi"))
  assert_true(summary.contains("2026-01-01"))
}

///|
/// Sanitize text
test "sanitize_text" {
  assert_eq(@Mr-Houjie/mbt-email.sanitize_text("a&lt;b"), "a<b")
}
