defmodule ReadabilityEx.Paging do
  @moduledoc false

  alias ReadabilityEx.Constants

  def append_next_pages(result, doc, base_uri, opts) do
    fetcher = opts[:page_fetcher]

    if is_nil(fetcher) do
      result
    else
      max_pages = opts[:max_pages] || 1
      {content, _visited} = collect_pages(result.content, doc, base_uri, fetcher, opts, max_pages)
      update_result(result, content)
    end
  end

  defp collect_pages(content_html, doc, base_uri, fetcher, opts, max_pages) do
    page_one = wrap_page(content_html, 1)

    Stream.unfold({doc, base_uri, MapSet.new(), 1}, fn
      {_doc, _base_uri, _visited, page} when page >= max_pages + 1 ->
        nil

      {doc, base_uri, visited, page} ->
        case find_next_page_link(doc, base_uri, visited) do
          nil ->
            nil

          url ->
            case fetch_page(fetcher, url) do
              {:ok, html} ->
                {:ok, next_doc} = Floki.parse_document(html)
                {{url, html, next_doc}, {next_doc, url, MapSet.put(visited, url), page + 1}}

              _ ->
                nil
            end
        end
    end)
    |> Enum.reduce({page_one, MapSet.new()}, fn {url, html, _doc}, {acc, visited} ->
      case ReadabilityEx.parse(html, next_page_opts(opts, url)) do
        {:ok, next_result} ->
          next_page = wrap_page(next_result.content, MapSet.size(visited) + 2)
          {acc <> next_page, MapSet.put(visited, url)}

        _ ->
          {acc, visited}
      end
    end)
  end

  defp next_page_opts(opts, url) do
    opts
    |> Keyword.put(:base_uri, url)
    |> Keyword.put(:page_fetcher, nil)
    |> Keyword.put(:max_pages, 0)
  end

  defp fetch_page(fetcher, url) when is_function(fetcher, 1) do
    case fetcher.(url) do
      {:ok, html} when is_binary(html) -> {:ok, html}
      html when is_binary(html) -> {:ok, html}
      other -> other
    end
  end

  def find_next_page_link(doc, base_uri, visited) do
    candidates =
      doc
      |> Floki.find("a[href]")
      |> Enum.map(fn link ->
        href = attr(link, "href")
        text = link |> Floki.text() |> normalize_text()
        rel = attr(link, "rel")
        match_string = attr(link, "class") <> " " <> attr(link, "id")

        score = score_link(rel, text, match_string)

        {score, href}
      end)
      |> Enum.reject(fn {_score, href} -> skip_href?(href) end)
      |> Enum.map(fn {score, href} -> {score, to_abs(href, base_uri)} end)
      |> Enum.reject(fn {_score, href} -> MapSet.member?(visited, href) end)

    case Enum.max_by(candidates, fn {score, _href} -> score end, fn -> nil end) do
      {score, href} when score > 0 -> href
      _ -> nil
    end
  end

  defp score_link(rel, text, match_string) do
    rel = String.downcase(rel || "")
    match_string = String.downcase(match_string || "")
    text = String.downcase(text || "")

    score =
      if String.contains?(rel, "next"), do: 50, else: 0

    score =
      if Regex.match?(Constants.re_next_link(), text) or
           Regex.match?(Constants.re_next_link(), match_string) do
        score + 25
      else
        score
      end

    score =
      if Regex.match?(Constants.re_prev_link(), text) or
           Regex.match?(Constants.re_prev_link(), match_string) do
        score - 50
      else
        score
      end

    score
  end

  defp skip_href?(href) do
    href in [nil, ""] or
      String.starts_with?(href, "#") or
      String.match?(href, ~r/^(mailto|tel|data|javascript|about):/i)
  end

  defp to_abs(url, base_uri) do
    base = URI.parse(base_uri || "")
    uri = URI.parse(url)

    cond do
      uri.scheme in ["http", "https"] ->
        url

      String.starts_with?(url, "//") ->
        (base.scheme || "https") <> ":" <> url

      true ->
        if base.path in [nil, ""] do
          URI.merge(%{base | path: "/"}, uri) |> URI.to_string()
        else
          URI.merge(base, uri) |> URI.to_string()
        end
    end
  end

  defp wrap_page(content, page_number) do
    id = "readability-page-#{page_number}"
    "<div id=\"#{id}\" class=\"page\">#{content}</div>"
  end

  defp update_result(result, content_html) do
    text =
      content_html
      |> Floki.parse_fragment!()
      |> Floki.text()

    %{result | content: content_html, textContent: text, length: String.length(text)}
  end

  defp normalize_text(text) do
    text
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp attr(node, key) do
    node
    |> Floki.attribute(key)
    |> List.first()
    |> to_string()
  end
end
