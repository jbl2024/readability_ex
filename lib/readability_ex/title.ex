defmodule ReadabilityEx.Title do
  @moduledoc false

  def get_article_title(doc, meta, _opts) do
    meta_title = meta.title |> blank()
    raw = doc |> Floki.find("title") |> Floki.text() |> String.trim()

    cond do
      meta_title != "" ->
        get_title_from_raw(doc, meta_title)

      true ->
        get_title_from_raw(doc, raw)
    end
  end

  defp get_title_from_raw(_doc, ""), do: ""

  defp get_title_from_raw(doc, raw) do
    orig_title = raw
    word_count = fn s -> String.split(s, ~r/\s+/, trim: true) |> length() end

    {cur_title, title_had_hierarchical_separators} =
      if Regex.match?(~r/\s[|\-–—\\\/>»]\s/, orig_title) do
        title_had_hierarchical_separators = Regex.match?(~r/\s[\\\/>»]\s/, orig_title)
        matches = Regex.scan(~r/\s[|\-–—\\\/>»]\s/, orig_title, return: :index)

        cur_title =
          case List.flatten(matches) |> List.last() do
            {idx, _len} ->
              String.slice(orig_title, 0, idx)

            _ ->
              orig_title
          end

        cur_title =
          if word_count.(cur_title) < 3 do
            Regex.replace(
              ~r/^[^|\-–—\\\/>»]*[|\-–—\\\/>»]/,
              orig_title,
              ""
            )
          else
            cur_title
          end

        {cur_title, title_had_hierarchical_separators}
      else
        cur_title =
          if String.contains?(orig_title, ": ") do
            headings =
              doc
              |> Floki.find("h1,h2")
              |> Enum.map(&Floki.text/1)
              |> Enum.map(&String.trim/1)

            trimmed = String.trim(orig_title)
            match = Enum.any?(headings, fn heading -> heading == trimmed end)

            if not match do
              case last_index(orig_title, ":") do
                nil ->
                  orig_title

                idx ->
                  String.slice(orig_title, (idx + 1)..-1)
              end
              |> then(fn title ->
                if word_count.(title) < 3 do
                  case first_index(orig_title, ":") do
                    nil ->
                      orig_title

                    first_idx ->
                      new_title = String.slice(orig_title, (first_idx + 1)..-1)

                      if word_count.(String.slice(orig_title, 0, first_idx)) > 5 do
                        orig_title
                      else
                        new_title
                      end
                  end
                else
                  title
                end
              end)
            else
              orig_title
            end
          else
            if String.length(orig_title) > 150 or String.length(orig_title) < 15 do
              h1s = Floki.find(doc, "h1")

              if length(h1s) == 1 do
                h1s |> List.first() |> Floki.text()
              else
                orig_title
              end
            else
              orig_title
            end
          end

        {cur_title, false}
      end

    cur_title =
      cur_title
      |> String.trim()
      |> String.replace(~r/\s{2,}/, " ")

    cur_title_word_count = word_count.(cur_title)

    if cur_title_word_count <= 4 and
         (!title_had_hierarchical_separators or
            cur_title_word_count !=
              word_count.(Regex.replace(~r/\s[|\-–—\\\/>»]\s/, orig_title, "")) - 1) do
      orig_title
    else
      cur_title
    end
  end

  defp first_index(str, pattern) do
    case :binary.match(str, pattern) do
      {idx, _len} -> idx
      :nomatch -> nil
    end
  end

  defp last_index(str, pattern) do
    case :binary.matches(str, pattern) do
      [] -> nil
      matches -> matches |> List.last() |> elem(0)
    end
  end

  defp blank(nil), do: ""
  defp blank(s), do: String.trim(s || "")
end
