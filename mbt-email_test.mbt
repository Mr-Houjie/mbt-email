/// Black-box tests for mbt-email.

///| Simple message parsing with basic headers
test "parse_simple_message" {
  let input = "From: alice@example.com\r\nTo: bob@example.com\r\nSubject: Test\r\n\r\nHello, world!\r\n"
  let msg = @houjie/mbt-email.parse(input)

  // Check headers
  let from = @houjie/mbt-email.get_header(msg, "From")
  assert_eq(from, Some("alice@example.com"))

  let to = @houjie/mbt-email.get_header(msg, "To")
  assert_eq(to, Some("bob@example.com"))

  let subject = @houjie/mbt-email.get_header(msg, "Subject")
  assert_eq(subject, Some("Test"))

  // Check body
  match msg.body {
    Some(b) => assert_eq(b.trim(chars=" \t\r\n").to_owned(), "Hello, world!")
    None => assert_true(false)
  }
}

///| Parse email address in simple format
test "parse_simple_address" {
  let addr = @houjie/mbt-email.parse_address("user@example.com")
  match addr {
    Some(a) => {
      assert_eq(a.local_part, "user")
      assert_eq(a.domain, "example.com")
    }
    None => assert_true(false)
  }
}

///| Parse email address in angle-addr format
test "parse_angle_address" {
  let addr = @houjie/mbt-email.parse_address("<user@example.com>")
  match addr {
    Some(a) => {
      assert_eq(a.local_part, "user")
      assert_eq(a.domain, "example.com")
    }
    None => assert_true(false)
  }
}

///| Parse email address with display name
test "parse_display_name_address" {
  let addr = @houjie/mbt-email.parse_address("Alice <alice@example.com>")
  match addr {
    Some(a) => {
      assert_eq(a.local_part, "alice")
      assert_eq(a.domain, "example.com")
    }
    None => assert_true(false)
  }
}

///| Parse invalid address returns None
test "parse_invalid_address" {
  let addr = @houjie/mbt-email.parse_address("not-an-email")
  assert_true(addr is None)
}

///| Parse empty address returns None
test "parse_empty_address" {
  let addr = @houjie/mbt-email.parse_address("")
  assert_true(addr is None)
}

///| Parse multiple addresses from a list
test "parse_address_list_multiple" {
  let list = @houjie/mbt-email.parse_address_list(
    "alice@example.com, bob@example.com, carol@example.com"
  )
  assert_eq(list.length(), 3)
  assert_eq(list[0].local_part, "alice")
  assert_eq(list[1].local_part, "bob")
  assert_eq(list[2].local_part, "carol")
}

///| Parse address list with angle brackets
test "parse_address_list_with_angles" {
  let list = @houjie/mbt-email.parse_address_list(
    "Alice <alice@example.com>, Bob <bob@example.com>"
  )
  assert_eq(list.length(), 2)
  assert_eq(list[0].local_part, "alice")
  assert_eq(list[1].local_part, "bob")
}

///| Parse Content-Type header
test "parse_content_type_plain" {
  let ct = @houjie/mbt-email.parse_content_type("text/plain; charset=utf-8")
  match ct {
    Some(c) => {
      assert_eq(c.media_type, "text")
      assert_eq(c.sub_type, "plain")
      assert_eq(c.params.length(), 1)
      assert_eq(c.params[0].0, "charset")
      assert_eq(c.params[0].1, "utf-8")
    }
    None => assert_true(false)
  }
}

///| Parse Content-Type with quoted parameter
test "parse_content_type_with_quoted_param" {
  let ct = @houjie/mbt-email.parse_content_type(
    "multipart/mixed; boundary=\"----=_Part_123\""
  )
  match ct {
    Some(c) => {
      assert_eq(c.media_type, "multipart")
      assert_eq(c.sub_type, "mixed")
      assert_eq(c.params.length(), 1)
      assert_eq(c.params[0].0, "boundary")
      assert_eq(c.params[0].1, "----=_Part_123")
    }
    None => assert_true(false)
  }
}

///| Parse Content-Disposition
test "parse_content_disposition_attachment" {
  let cd = @houjie/mbt-email.parse_content_disposition(
    "attachment; filename=document.pdf"
  )
  match cd {
    Some(d) => {
      assert_eq(d.disposition, "attachment")
      assert_eq(d.params.length(), 1)
      assert_eq(d.params[0].0, "filename")
      assert_eq(d.params[0].1, "document.pdf")
    }
    None => assert_true(false)
  }
}

///| Parse Content-Disposition inline
test "parse_content_disposition_inline" {
  let cd = @houjie/mbt-email.parse_content_disposition("inline")
  match cd {
    Some(d) => {
      assert_eq(d.disposition, "inline")
      assert_eq(d.params.length(), 0)
    }
    None => assert_true(false)
  }
}

///| Decode RFC 2047 Base64 encoded-word
test "decode_encoded_word_base64" {
  let decoded = @houjie/mbt-email.decode_encoded_word("=?UTF-8?B?SGVsbG8=?=")
  match decoded {
    Some(s) => assert_eq(s, "Hello")
    None => assert_true(false)
  }
}

///| Decode RFC 2047 Q-encoded word
test "decode_encoded_word_q" {
  let decoded = @houjie/mbt-email.decode_encoded_word("=?UTF-8?Q?Hello_World?=")
  match decoded {
    Some(s) => assert_eq(s, "Hello World")
    None => assert_true(false)
  }
}

///| Decode invalid encoded-word returns None
test "decode_invalid_encoded_word" {
  let decoded = @houjie/mbt-email.decode_encoded_word("not-an-encoded-word")
  assert_true(decoded is None)
}

///| Round-trip: parse then serialize simple message
test "roundtrip_simple_message" {
  let input = "From: alice@example.com\r\nTo: bob@example.com\r\nSubject: Test\r\n\r\nHello!\r\n"
  let msg = @houjie/mbt-email.parse(input)
  let output = @houjie/mbt-email.to_string(msg)
  assert_eq(output, input)
}

///| Serialize email address
test "serialize_address" {
  let addr = @houjie/mbt-email.email_address(local_part="user", domain="example.com")
  let s = @houjie/mbt-email.address_to_string(addr)
  assert_eq(s, "user@example.com")
}

///| Serialize email address that needs quoting
test "serialize_address_with_special_chars" {
  let addr = @houjie/mbt-email.email_address(local_part="user name", domain="example.com")
  let s = @houjie/mbt-email.address_to_string(addr)
  assert_eq(s, "\"user name\"@example.com")
}

///| Get header case-insensitive
test "get_header_case_insensitive" {
  let msg = @houjie/mbt-email.parse("From: alice@example.com\r\n\r\nHi\r\n")
  let from1 = @houjie/mbt-email.get_header(msg, "From")
  let from2 = @houjie/mbt-email.get_header(msg, "from")
  let from3 = @houjie/mbt-email.get_header(msg, "FROM")
  assert_eq(from1, Some("alice@example.com"))
  assert_eq(from2, Some("alice@example.com"))
  assert_eq(from3, Some("alice@example.com"))
}

///| Get multiple headers with same name
test "get_multiple_headers" {
  let input =
    "Received: from server1\r\n" +
    "Received: from server2\r\n" +
    "\r\n" +
    "Body\r\n"
  let msg = @houjie/mbt-email.parse(input)
  let received = @houjie/mbt-email.get_headers(msg, "Received")
  assert_eq(received.length(), 2)
  assert_eq(received[0], "from server1")
  assert_eq(received[1], "from server2")
}

///| Empty message parsing
test "parse_empty_message" {
  let msg = @houjie/mbt-email.parse("")
  assert_eq(msg.headers.length(), 0)
  assert_true(msg.body is None)
}
