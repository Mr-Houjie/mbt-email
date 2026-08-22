# mbt-email

An RFC 5322/2045 email address and MIME message parser written in pure MoonBit.

Parses raw email text into a structured MoonBit AST and serializes it back into
standards-compliant text — foundational email-protocol handling for the MoonBit
ecosystem, with zero external dependencies.

> The full documentation lives in [README.mbt.md](README.mbt.md).

## Install

```bash
moon add Mr-Houjie/mbt-email
```

Or clone and build from source:

```bash
git clone https://github.com/Mr-Houjie/mbt-email.git
cd mbt-email
moon build
```

## Quick start

```moonbit nocheck
let input =
  "From: alice@example.com\r\n" +
  "To: bob@example.com\r\n" +
  "Subject: Hello\r\n" +
  "\r\n" +
  "Hello, world!\r\n"

let msg = @Mr-Houjie/mbt-email.parse(input)
let subject = @Mr-Houjie/mbt-email.message_subject(msg) // "Hello"
let text = @Mr-Houjie/mbt-email.to_string(msg)
```

## CLI

```bash
moon run cmd/main
```

## Test

```bash
moon test
```

## License

MIT
