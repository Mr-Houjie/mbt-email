# mbt-email

An RFC 5322/2045 email address and MIME message parser written in pure MoonBit.

`mbt-email` parses raw email text into a structured MoonBit AST (built on algebraic
data types) and serializes it back into standards-compliant text, providing
foundational email-protocol handling for the MoonBit ecosystem.

## Features

- **RFC 5322 email address parsing**: dot-atom, quoted-string, domain-literal, and
  display-name mailboxes (`Alice <alice@example.com>`)
- **RFC 5322 message headers**: From, To, Cc, Subject, Date, Message-ID, Received,
  References, In-Reply-To, etc.
- **RFC 2045/2046 MIME parsing**: multipart/mixed, multipart/alternative,
  multipart/related, recursive nested part trees
- **Content-Type / Content-Disposition parsing**: media type, subtype, and
  parameters (charset, boundary, name, filename)
- **RFC 2047 encoded-word decoding**: `=?UTF-8?B?base64?=` → decoded text
- **RFC 2231 extended parameters**: `filename*0*` continuation merging and
  percent-decoding
- **Transfer codecs**: Base64 and Quoted-Printable (encode + decode)
- **Date handling**: RFC 5322 date-time parsing, validation, timestamp conversion
- **Parse to AST**: `parse()` / `parse_mime()` convert raw email text into a `Message`
- **Serialize back**: `to_string()` converts AST back to RFC-compliant text
- **Build helpers**: construct text / HTML / multipart / attachment messages
- **Zero external dependencies**: pure MoonBit, no third-party packages

## Installation

### From mooncakes.io

```bash
moon add Mr-Houjie/mbt-email
```

Then import the package in your `moon.pkg`:

```moonbit nocheck
///|
let msg = @Mr-Houjie/mbt-email.parse(input)
```

### From source

```bash
git clone https://github.com/Mr-Houjie/mbt-email.git
cd mbt-email
moon build
```

## Usage

### Parse an email message

```moonbit nocheck
///|
let input = "From: alice@example.com\r\n" +
  "To: bob@example.com\r\n" +
  "Subject: Hello\r\n" +
  "\r\n" +
  "Hello, world!\r\n"

///|
let msg = @Mr-Houjie/mbt-email.parse(input)
```

### Access headers

```moonbit nocheck
///|
let from = @Mr-Houjie/mbt-email.get_header(msg, "From")

///|
let subject = @Mr-Houjie/mbt-email.message_subject(msg)
```

### Parse email addresses

```moonbit nocheck
///|
let addrs = @Mr-Houjie/mbt-email.parse_address_list(
  "Alice <a@example.com>, Bob <b@example.com>",
)
```

### Parse a MIME message with attachments

```moonbit nocheck
///|
let msg = @Mr-Houjie/mbt-email.parse_mime(input)
```

### Serialize back to RFC text

```moonbit nocheck
///|
let text = @Mr-Houjie/mbt-email.to_string(msg)
```

## CLI

```bash
moon run cmd/main
```

The CLI parses a demo email and prints parsed headers, addresses, body, and the
round-trip serialization.

## API reference

All entry points are in the top-level `@Mr-Houjie/mbt-email` package.

### Entry points

| Function | Description |
|---|---|
| `parse(input)` | Parse raw email text into a `Message` |
| `parse_mime(input)` | Parse a MIME message with full multipart support |
| `to_string(msg)` | Serialize a `Message` back to RFC 5322 text |

### Addresses

| Function | Description |
|---|---|
| `parse_address(input)` | Parse a single `user@domain` address |
| `parse_address_list(input)` | Parse a comma-separated address list |
| `parse_mailbox(input)` | Parse a mailbox with optional display name |
| `parse_mailbox_list(input)` | Parse a mailbox list |
| `validate_email_address(addr)` / `validate_domain` / `validate_local_part` | Validate address components |
| `address_to_string` / `mailbox_to_string` | Format back to text |

### MIME

| Function | Description |
|---|---|
| `parse_content_type(value)` | Parse a `Content-Type` header value |
| `parse_content_disposition(value)` | Parse a `Content-Disposition` value |
| `collect_attachments(part)` | Collect attachment MIME parts |
| `part_filename(part)` | Extract the filename of a part |
| `plain_text(part)` | Extract plain text from a MIME tree |
| `message_content_type` / `message_boundary` | Read a message's MIME info |

### Headers & encoding

| Function | Description |
|---|---|
| `decode_header_value(input)` | Decode RFC 2047 encoded-words in a header |
| `decode_encoded_word(input)` | Decode a single encoded-word |
| `decode_rfc2231_value` / `merge_extended_params` | Decode RFC 2231 parameters |
| `get_header` / `get_headers` / `has_header` | Look up headers (case-insensitive) |

### Dates & misc

| Function | Description |
|---|---|
| `parse_email_date(input)` | Parse an RFC 5322 date-time |
| `email_date_to_string` / `format_rfc5322_date` | Format a date |
| `to_timestamp` / `compare_dates` | Date conversions |
| `b64_encode_text` / `b64_decode_text` / `qp_encode_text` / `qp_decode` | Transfer codecs |
| `message_subject` / `message_from_mailboxes` / `message_cc_mailboxes` | Message-level helpers |
| `make_text_message` / `make_html_message` / `make_multipart_message` | Build messages |

## Project structure

```
mbt-email/
├── lexer.mbt       # Tokenizer (RFC 5322 / MIME tokens)
├── parser.mbt      # Recursive-descent parser
├── ast.mbt         # AST types (EmailAddress, Header, MimePart, Message)
├── serializer.mbt  # AST → RFC 5322 text
├── address.mbt     # Address & mailbox parsing
├── header.mbt      # Header value decoding (RFC 2047 / 2231)
├── mime.mbt        # Recursive multipart MIME parsing
├── codec.mbt       # Base64 / Quoted-Printable codecs
├── datetime.mbt    # RFC 5322 date-time
├── message.mbt     # Message-level helpers
├── build.mbt       # Message construction & serialization
├── utils.mbt       # Utilities (UTF-8, HTML escaping, URL encoding)
└── cmd/main/       # CLI example
```

## Building

```bash
moon build
```

## Testing

```bash
moon test
```

## License

[MIT](LICENSE)
