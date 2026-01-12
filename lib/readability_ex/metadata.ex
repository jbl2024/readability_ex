defmodule ReadabilityEx.Metadata do
  @moduledoc false

  @jsonld_types MapSet.new([
                  "Article",
                  "NewsArticle",
                  "BlogPosting",
                  "Report",
                  "ScholarlyArticle"
                ])

  def extract(doc, raw_html) do
    jsonld = get_jsonld(raw_html)
    meta = get_meta(doc)

    %{
      title: jsonld[:title] || meta[:title],
      excerpt: jsonld[:excerpt] || meta[:description],
      byline: normalize_author(meta[:author]) || normalize_author(jsonld[:author]),
      site_name: normalize_site_name(meta[:site_name]),
      lang: meta[:lang],
      published_time: jsonld[:published_time] || meta[:published_time],
      dir: meta[:dir]
    }
  end

  def get_direction(top_id, state) do
    crawl_dir(top_id, state)
  end

  defp crawl_dir(nil, _), do: nil

  defp crawl_dir(id, state) do
    case state[id] do
      nil ->
        nil

      n ->
        if n.dir && n.dir != "" do
          n.dir
        else
          crawl_dir(n.parent_id, state)
        end
    end
  end

  defp get_meta(doc) do
    %{
      title:
        meta_content(doc, [
          "dc:title",
          "DC.title",
          "dcterms.title",
          "DCTERMS.title",
          "parsely-title",
          "og:title",
          "twitter:title",
          "title"
        ]),
      description:
        meta_content(doc, [
          "dc:description",
          "DC.description",
          "dcterms.description",
          "DCTERMS.description",
          "og:description",
          "twitter:description",
          "description"
        ]),
      author:
        meta_content(doc, [
          "dc:creator",
          "DC.creator",
          "dcterms.creator",
          "DCTERMS.creator",
          "author",
          "parsely-author",
          "article:author"
        ]),
      site_name: meta_content(doc, ["og:site_name"]),
      published_time:
        meta_content(doc, [
          "article:published_time",
          "og:published_time",
          "parsely-pub-date"
        ]),
      lang: Floki.attribute(doc, "html", "lang") |> List.first() |> blank_to_nil(),
      dir: Floki.attribute(doc, "html", "dir") |> List.first() |> blank_to_nil()
    }
  end

  defp meta_content(doc, keys) do
    metas = Floki.find(doc, "meta")

    Enum.find_value(keys, fn key ->
      Enum.find_value(metas, fn meta ->
        attrs =
          Floki.attribute(meta, "property") ++
            Floki.attribute(meta, "name") ++ Floki.attribute(meta, "itemprop")

        content = meta |> Floki.attribute("content") |> List.first() |> blank_to_nil()

        if content && Enum.any?(attrs, &meta_key_match?(&1, key)) do
          content
        else
          nil
        end
      end)
    end)
  end

  defp meta_key_match?(attr, key) do
    key = String.downcase(key)

    attr
    |> String.downcase()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.any?(&(&1 == key))
  end

  defp get_jsonld(raw_html) do
    # Parse <script type="application/ld+json"> blocks from raw HTML (safer than after removal).
    blocks =
      Regex.scan(
        ~r/<script[^>]*type=["']application\/ld\+json["'][^>]*>(.*?)<\/script>/is,
        raw_html
      )
      |> Enum.map(fn [_, body] -> body end)

    blocks
    |> Enum.map(&decode_jsonld/1)
    |> Enum.reject(&is_nil/1)
    |> pick_best_jsonld()
  end

  defp decode_jsonld(body) do
    body =
      body
      |> String.trim()
      |> String.replace(~r/<!\[CDATA\[/, "")
      |> String.replace(~r/\]\]>/, "")
      |> String.trim()

    with {:ok, json} <- Jason.decode(body) do
      normalize_jsonld(json)
    else
      _ -> nil
    end
  end

  defp normalize_jsonld(list) when is_list(list) do
    list
    |> Enum.map(&normalize_jsonld/1)
    |> Enum.reject(&is_nil/1)
    |> List.first()
  end

  defp normalize_jsonld(%{"@graph" => graph}) when is_list(graph) do
    normalize_jsonld(graph)
  end

  defp normalize_jsonld(map) when is_map(map) do
    type =
      case map["@type"] do
        t when is_binary(t) -> t
        [t | _] when is_binary(t) -> t
        _ -> nil
      end

    if type && MapSet.member?(@jsonld_types, type) do
      %{
        title: (map["headline"] || map["name"]) |> blank_to_nil(),
        author: extract_author(map["author"]),
        published_time: (map["datePublished"] || map["dateCreated"]) |> blank_to_nil(),
        excerpt: map["description"] |> blank_to_nil()
      }
    else
      nil
    end
  end

  defp extract_author(nil), do: nil
  defp extract_author(%{"name" => n}), do: blank_to_nil(n)

  defp extract_author(list) when is_list(list),
    do: list |> Enum.map(&extract_author/1) |> Enum.find(& &1)

  defp extract_author(n) when is_binary(n), do: blank_to_nil(n)
  defp extract_author(_), do: nil

  defp pick_best_jsonld([]), do: %{}
  defp pick_best_jsonld([one]), do: one

  defp pick_best_jsonld(list) do
    Enum.find(list, &(&1[:title] && &1[:published_time])) || hd(list)
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(s) when is_binary(s) do
    s = String.trim(s)
    if s == "", do: nil, else: s
  end

  defp normalize_author(nil), do: nil

  defp normalize_author(author) when is_binary(author) do
    trimmed = String.trim(author)

    if Regex.match?(~r/^\w+:\/\//, trimmed) do
      nil
    else
      blank_to_nil(trimmed)
    end
  end

  defp normalize_site_name(nil), do: nil

  defp normalize_site_name(name) when is_binary(name) do
    name = String.trim(name)

    if name == "" do
      nil
    else
      if Regex.match?(~r/\s[|\-»:–—]\s|[|\-»:–—]/, name) do
        left =
          name
          |> String.replace(~r/\s*[|\-»:–—]\s*.+$/, "")
          |> String.trim()

        if String.contains?(left, ".") do
          left
        else
          name
        end
      else
        name
      end
    end
  end
end
