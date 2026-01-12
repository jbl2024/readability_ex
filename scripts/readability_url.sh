#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <url>" >&2
  exit 2
fi

url="$1"
tmp_html="$(mktemp -t readability_ex.XXXXXX.html)"
cleanup() {
  rm -f "$tmp_html"
}
trap cleanup EXIT

curl -fsSL "$url" -o "$tmp_html"

mix run -e '
[page_url, path] = System.argv()
html = File.read!(path)

case ReadabilityEx.parse(html, base_uri: page_url) do
  {:ok, result} ->
    IO.write(result.content)

  {:error, reason} ->
    IO.puts(:stderr, "readability_ex error: #{inspect(reason)}")
    System.halt(1)
end
' -- "$url" "$tmp_html"
