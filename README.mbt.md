# mbt-markdown

A Markdown-to-HTML parser and renderer written in MoonBit.

## Features

- **ATX Headings**: `#` to `######`
- **Paragraphs** with inline formatting
- **Emphasis**: `*italic*` and `**bold**`
- **Inline code**: `` `code` ``
- **Fenced code blocks**: ` ```lang ... ``` ` with optional language hint
- **Links**: `[text](url)` with optional title
- **Images**: `![alt](url)` with optional title
- **Blockquotes**: `> text`
- **Ordered and unordered lists**
- **Thematic breaks**: `---`, `***`, `___`
- **HTML escaping**: `&`, `<`, `>`, `"`, `'`

## Usage

### As a library

```moonbit
let html = @houjie/mbt-markdown.md_to_html("# Hello\n\nWorld")
// <h1>Hello</h1>
// <p>World</p>
```

Or parse to AST:

```moonbit
let doc = @houjie/mbt-markdown.parse("# Hello")
// doc.blocks[0] is Heading(1, [Text("Hello")])
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

Apache-2.0
