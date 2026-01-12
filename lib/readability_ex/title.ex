defmodule ReadabilityEx.Title do
  @moduledoc false

  # Common separators similar to Readability.js behavior
  @seps ~r/\s[|\-»:–—]\s|[|\-»:–—]/

  def get_article_title(doc, meta, _opts) do
    meta_title = meta.title |> blank()

    if meta_title != "" do
      refine_title(meta_title, doc)
    else
      raw = doc |> Floki.find("title") |> Floki.text() |> String.trim()
      refine_title(raw, doc)
    end
  end

  defp refine_title("", _doc), do: "Untitled"

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
    cand1 =
      raw
      |> String.replace(~r/\s*[|\-»:–—]\s*[^|\-»:–—]+$/, "")
      |> String.trim()

    cand2 =
      raw
      |> String.replace(~r/^[^|\-»:–—]+\s*[|\-»:–—]\s*/, "")
      |> String.trim()

    cond do
      word_count(cand1) >= 3 -> cand1
      word_count(cand2) >= 3 -> cand2
      true -> raw
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

  defp blank(nil), do: ""
  defp blank(s), do: String.trim(s || "")
end
