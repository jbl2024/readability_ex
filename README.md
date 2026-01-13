# ReadabilityEx

High-fidelity Elixir port of Mozilla Readability.js focused on extracting the
main article content from full HTML documents.

This project is derived from Mozilla Readability.js and is distributed under
the Apache 2.0 license.

## Upstream attribution

- Mozilla Readability.js source code: https://github.com/mozilla/readability/
- Mozilla Readability test suite (fixtures): https://github.com/mozilla/readability/tree/main/test/test-pages

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `readability_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:readability_ex, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Usage

Basic usage with a string of HTML:

```elixir
{:ok, result} =
  ReadabilityEx.parse(html, base_uri: "https://example.com/article")

IO.puts(result.content)
```

`result.content` is cleaned HTML. `result.textContent` is a plain-text version,
and `result.length` is the character count of the extracted text.

## CLI script

A small helper script is included to fetch a URL with `curl` and run the parser:

```bash
./scripts/readability_url.sh "https://example.com/article"
```

The script writes cleaned HTML to stdout. It exits non-zero if parsing fails.
Make sure dependencies are installed first (`mix deps.get`).

## API docs

### `ReadabilityEx.parse/2`

```elixir
ReadabilityEx.parse(html, opts \\ [])
```

Returns `{:ok, result}` or `{:error, :not_readable}`.

`result` is a map with:

- `:title` - detected article title
- `:content` - cleaned HTML string
- `:textContent` - plain-text content
- `:length` - character count of `textContent`
- `:excerpt` - short excerpt, when available
- `:byline` - author byline, when available
- `:dir` - text direction, when available
- `:siteName` - site name from metadata, when available
- `:lang` - language from metadata, when available
- `:publishedTime` - published time, when available

## Options

`parse/2` accepts a keyword list or map:

- `:char_threshold` (default: `500`) - minimum extracted text length required
  to accept a pass
- `:base_uri` (default: `nil`) - base URL used to absolutize links and image
  sources; if an HTML `<base>` tag exists, it is respected
- `:nb_top_candidates` (default: `5`) - number of top candidates kept for
  scoring
- `:preserve_classes` (default: `MapSet.new(["page", "caption", "OPEN", "CLOSE", "ORD"])`) -
  classes to keep when stripping attributes/classes
- `:keep_classes` (default: `false`) - keep all class attributes in output HTML
- `:page_fetcher` (default: `nil`) - function to fetch next-page HTML for paging
- `:max_pages` (default: `1`) - maximum number of additional pages to append

## Examples

Extract from a local HTML file:

```elixir
html = File.read!("test/fixtures/readability-test-pages/wikipedia/source.html")

{:ok, result} =
  ReadabilityEx.parse(html, base_uri: "https://en.wikipedia.org/wiki/Readability")

File.write!("cleaned.html", result.content)
```

Customize options:

```elixir
{:ok, result} =
  ReadabilityEx.parse(html,
    base_uri: "https://example.com/",
    char_threshold: 200,
    nb_top_candidates: 8,
    preserve_classes: MapSet.new(["page", "caption", "lead"]),
    keep_classes: false,
    page_fetcher: nil,
    max_pages: 1
  )
```

## Troubleshooting

- `{:error, :not_readable}` usually means the extracted text was too short or
  no suitable content was found. Try lowering `:char_threshold` or verify the
  HTML is a full document rather than a fragment.
- Relative URLs are only absolutized when `:base_uri` is set or the document
  includes a `<base>` tag.
- If `ReadabilityEx.parse/2` raises, ensure the input is valid HTML. You can
  wrap calls with `try/rescue` when working with untrusted inputs.
- If the CLI script fails, confirm `curl` is installed and `mix deps.get` has
  been run.

## Development

- `mix test`
- `mix format`
- `mix credo`

## License

Apache 2.0. See `LICENSE`.
