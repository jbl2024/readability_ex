defmodule ReadabilityEx.Title do
  @moduledoc false

  # Common separators similar to Readability.js behavior
  @seps ~r/\s[\|\-»:\u2013\u2014]\s|[\|\-»:\u2013\u2014]/

  def get_article_title(doc, meta, _opts) do
    meta_title = meta.title |> blank()

    if meta_title != "" do
      meta_title
    else
      raw = doc |> Floki.find("title") |> Floki.text() |> String.trim()
      refine_title(raw, doc)
    end
  end

  defp refine_title("", _doc), do: "Untitled"

  defp refine_title(raw, doc) do
    parts =
      raw
      |> String.split(@seps, trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    best =
      case parts do
        [] -> raw
        [one] -> one
        many -> choose_side(many)
      end

    best = verify_with_h1(best, doc) || best
    best
  end

  defp choose_side(parts) do
    # Prefer stripping site name at end; if too short, try other side.
    cand1 = parts |> Enum.drop(-1) |> Enum.join(" ") |> String.trim()
    cand2 = parts |> tl() |> Enum.join(" ") |> String.trim()

    cond do
      word_count(cand1) >= 3 -> cand1
      word_count(cand2) >= 3 -> cand2
      true -> Enum.at(parts, 0)
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

  defp word_count(s), do: s |> String.split(~r/\s+/, trim: true) |> length()
  defp blank(nil), do: ""
  defp blank(s), do: String.trim(s || "")
end
