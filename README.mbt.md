# mbt-email

An RFC 5322/2045 email address and MIME message parser written in pure MoonBit.

## Features

- **RFC 5322 email address parsing**: `user@domain`, quoted-string, domain-literal
- **RFC 5322 message headers**: From, To, Cc, Subject, Date, Message-ID
- **RFC 2045/2046 MIME parsing**: multipart messages, Content-Type, Content-Disposition
- **RFC 2047 encoded-word decoding**: `=?UTF-8?B?base64?=` → decoded text
- **Parse to AST**: `parse()` converts raw email text into a structured AST
- **Serialize back**: `to_string()` converts AST back to RFC-compliant text

## Usage

### As a library

```moonbit
// Parse an email message
let msg = @houjie/mbt-email.parse(
  "From: alice@example.com\r\n" +
  "To: bob@example.com\r\n" +
  "Subject: Hello\r\n" +
  "\r\n" +
  "Hello, world!\r\n"
)

// Access headers
let from = @houjie/mbt-email.get_header(msg, "From")

// Serialize back to text
let text = @houjie/mbt-email.to_string(msg)
```

### CLI

```bash
moon run cmd/main
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

MIT
