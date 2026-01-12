defmodule ReadabilityEx.Title do
  @moduledoc false

  # Common separators similar to Readability.js behavior
  @seps ~r/\s[|»:–—-]\s|\s*\|\s*/

  def get_article_title(doc, meta, _opts) do
    meta_title = meta.title |> blank()
    raw = doc |> Floki.find("title") |> Floki.text() |> String.trim()

    cond do
      meta_title != "" and meta_title != raw ->
        String.trim(meta_title)

      meta_title != "" ->
        refine_title(meta_title, doc)

      true ->
        refine_title(raw, doc)
    end
  end

  defp refine_title("", _doc), do: ""

  defp refine_title(raw, doc) do
    best =
      if Regex.match?(@seps, raw) do
        choose_side(raw)
      else
        raw
      end

    best = verify_with_h1(best, doc) || best
    best
  end

  defp choose_side(raw) do
    # Prefer stripping site name at end; if too short, try other side.
    parts = String.split(raw, ~r/\s*\|\s*|\s+[-–—:]\s+/)
    parts = Enum.map(parts, &String.trim/1)

    cond do
      length(parts) >= 3 and looks_like_author?(List.last(parts)) ->
        parts |> Enum.drop(-1) |> Enum.join(" | ")

      true ->
        cand1 = parts |> List.first() |> to_string() |> String.trim()
        cand2 = parts |> List.last() |> to_string() |> String.trim()

        cond do
          word_count(cand1) >= 3 -> cand1
          word_count(cand2) >= 3 -> cand2
          true -> raw
        end
    end
  end

  defp verify_with_h1(title, doc) do
    h =
      doc
      |> Floki.find("h1,h2")
      |> Enum.map(&Floki.text/1)
      |> Enum.map(&String.trim/1)

    if Enum.any?(h, fn t -> normalize(t) == normalize(title) end), do: title, else: nil
  end

  defp normalize(s) do
    s
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp word_count(s) do
    s
    |> String.replace(@seps, " ")
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end

  defp looks_like_author?(part) do
    words = String.split(part, ~r/\s+/, trim: true)

    length(words) in 2..3 and
      Enum.all?(words, fn w ->
        String.match?(w, ~r/^[A-Z][A-Za-z'’\-]+$/)
      end)
  end

  defp blank(nil), do: ""
  defp blank(s), do: String.trim(s || "")
end
