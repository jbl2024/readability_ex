defmodule ReadabilityEx.Metadata do
  @moduledoc false

  alias ReadabilityEx.Title

  @jsonld_types MapSet.new([
                  "Article",
                  "AdvertiserContentArticle",
                  "NewsArticle",
                  "AnalysisNewsArticle",
                  "AskPublicNewsArticle",
                  "BackgroundNewsArticle",
                  "OpinionNewsArticle",
                  "ReportageNewsArticle",
                  "ReviewNewsArticle",
                  "Report",
                  "SatiricalArticle",
                  "ScholarlyArticle",
                  "MedicalScholarlyArticle",
                  "SocialMediaPosting",
                  "BlogPosting",
                  "LiveBlogPosting",
                  "DiscussionForumPosting",
                  "TechArticle",
                  "APIReference"
                ])

  def extract(doc, raw_html) do
    article_title = Title.get_article_title(doc, %{title: ""}, [])
    jsonld = get_jsonld(raw_html, article_title)
    meta = get_meta(doc)

    %{
      title: jsonld[:title] || meta[:title],
      excerpt: jsonld[:excerpt] || meta[:description],
      byline:
        normalize_byl(meta[:byl]) ||
          normalize_author(meta[:author]) || normalize_author(jsonld[:author]),
      site_name: normalize_site_name(jsonld[:site_name] || meta[:site_name]),
      lang: meta[:lang],
      published_time: jsonld[:published_time] || meta[:published_time],
      dir: meta[:dir]
    }
    |> unescape_metadata_entities()
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
      byl: meta_content(doc, ["byl"]),
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

  defp get_jsonld(raw_html, article_title) do
    # Parse <script type="application/ld+json"> blocks from raw HTML (safer than after removal).
    blocks =
      Regex.scan(
        ~r/<script[^>]*type=["']application\/ld\+json["'][^>]*>(.*?)<\/script>/is,
        raw_html
      )
      |> Enum.map(fn [_, body] -> body end)

    blocks
    |> Enum.map(&decode_jsonld(&1, article_title))
    |> Enum.reject(&is_nil/1)
    |> pick_best_jsonld()
  end

  defp decode_jsonld(body, article_title) do
    body =
      body
      |> String.trim()
      |> String.replace(~r/<!\[CDATA\[/, "")
      |> String.replace(~r/\]\]>/, "")
      |> String.trim()

    with {:ok, json} <- Jason.decode(body) do
      normalize_jsonld(json, article_title)
    else
      _ -> nil
    end
  end

  defp normalize_jsonld(list, article_title) when is_list(list) do
    list
    |> Enum.find(&jsonld_article_type?/1)
    |> normalize_jsonld(article_title)
  end

  defp normalize_jsonld(nil, _article_title), do: nil

  defp normalize_jsonld(%{"@graph" => graph}, article_title) when is_list(graph) do
    normalize_jsonld(graph, article_title)
  end

  defp normalize_jsonld(map, article_title) when is_map(map) do
    if schema_org_context?(map) do
      map =
        if map["@type"] do
          map
        else
          map
          |> Map.get("@graph", [])
          |> Enum.find(&jsonld_article_type?/1)
        end

      if map && jsonld_article_type?(map) do
        %{
          title: jsonld_title(map["name"], map["headline"], article_title),
          author: extract_author(map["author"]),
          published_time: (map["datePublished"] || map["dateCreated"]) |> blank_to_nil(),
          excerpt: map["description"] |> blank_to_nil(),
          site_name: publisher_name(map["publisher"])
        }
      else
        nil
      end
    else
      nil
    end
  end

  defp extract_author(nil), do: nil
  defp extract_author(%{"name" => n}), do: blank_to_nil(n)

  defp extract_author(list) when is_list(list) do
    list
    |> Enum.map(&extract_author/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
    |> blank_to_nil()
  end

  defp extract_author(n) when is_binary(n), do: blank_to_nil(n)
  defp extract_author(_), do: nil

  defp pick_best_jsonld([]), do: %{}
  defp pick_best_jsonld([one]), do: one

  defp pick_best_jsonld(list) do
    Enum.find(list, &(&1[:title] && &1[:published_time])) || hd(list)
  end

  defp jsonld_article_type?(%{"@type" => type}), do: jsonld_article_type?(type)

  defp jsonld_article_type?(type) when is_binary(type) do
    MapSet.member?(@jsonld_types, type)
  end

  defp jsonld_article_type?(types) when is_list(types) do
    Enum.any?(types, &jsonld_article_type?/1)
  end

  defp jsonld_article_type?(_), do: false

  defp schema_org_context?(%{"@context" => context}), do: schema_org_context?(context)

  defp schema_org_context?(context) when is_binary(context) do
    Regex.match?(~r/^https?:\/\/schema\.org\/?$/i, context)
  end

  defp schema_org_context?(context) when is_map(context) do
    case Map.get(context, "@vocab") do
      nil -> false
      vocab -> schema_org_context?(vocab)
    end
  end

  defp schema_org_context?(_), do: false

  defp publisher_name(%{"name" => name}), do: blank_to_nil(name)
  defp publisher_name(_), do: nil

  defp jsonld_title(name, headline, article_title) do
    name = blank_to_nil(name)
    headline = blank_to_nil(headline)

    cond do
      is_binary(name) and is_binary(headline) and name != headline ->
        name_matches = text_similarity(name, article_title) > 0.75
        headline_matches = text_similarity(headline, article_title) > 0.75

        if headline_matches and not name_matches do
          headline
        else
          name
        end

      is_binary(name) ->
        name

      is_binary(headline) ->
        headline

      true ->
        nil
    end
  end

  defp text_similarity(text_a, text_b) do
    tokens_a = tokenize(text_a)
    tokens_b = tokenize(text_b)

    if tokens_a == [] or tokens_b == [] do
      0.0
    else
      token_set_a = MapSet.new(tokens_a)
      uniq_b = Enum.reject(tokens_b, &MapSet.member?(token_set_a, &1))
      distance_b =
        String.length(Enum.join(uniq_b, " ")) / max(1, String.length(Enum.join(tokens_b, " ")))

      1.0 - distance_b
    end
  end

  defp tokenize(text) do
    text
    |> to_string()
    |> String.downcase()
    |> String.split(~r/\W+/u, trim: true)
  end

  defp unescape_metadata_entities(metadata) do
    metadata
    |> Map.update(:title, nil, &unescape_html_entities/1)
    |> Map.update(:excerpt, nil, &unescape_html_entities/1)
    |> Map.update(:byline, nil, &unescape_html_entities/1)
    |> Map.update(:site_name, nil, &unescape_html_entities/1)
    |> Map.update(:published_time, nil, &unescape_html_entities/1)
  end

  defp unescape_html_entities(nil), do: nil
  defp unescape_html_entities(""), do: ""

  defp unescape_html_entities(text) when is_binary(text) do
    text
    |> String.replace(~r/&(?:quot|amp|apos|lt|gt);/, fn match ->
      case match do
        "&quot;" -> "\""
        "&amp;" -> "&"
        "&apos;" -> "'"
        "&lt;" -> "<"
        "&gt;" -> ">"
      end
    end)
    |> then(fn updated ->
      Regex.replace(~r/&#(?:x([0-9a-f]+)|([0-9]+));/i, updated, fn match, hex, num ->
        decoded =
          if is_nil(hex) do
            decode_codepoint(num, 10)
          else
            decode_codepoint(hex, 16)
          end

        decoded || match
      end)
    end)
  end

  defp decode_codepoint(value, base) do
    case Integer.parse(value, base) do
      {num, _} ->
        if num == 0 or num > 0x10FFFF or (num >= 0xD800 and num <= 0xDFFF) do
          <<0xFFFD::utf8>>
        else
          <<num::utf8>>
        end

      :error ->
        nil
    end
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

  defp normalize_byl(nil), do: nil

  defp normalize_byl(byl) when is_binary(byl) do
    byl =
      byl
      |> String.trim()
      |> then(&Regex.replace(~r/^by\s+/i, &1, ""))
      |> String.trim()

    byl =
      if all_caps_name?(byl) do
        titlecase(byl)
      else
        byl
      end

    blank_to_nil(byl)
  end

  defp all_caps_name?(text) do
    letters = Regex.scan(~r/\p{L}+/u, text) |> List.flatten()
    letters != [] and Enum.all?(letters, fn part -> part == String.upcase(part) end)
  end

  defp titlecase(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&titlecase_word/1)
    |> Enum.join(" ")
  end

  defp titlecase_word(word) do
    word
    |> String.split("-", trim: true)
    |> Enum.map(fn part -> part |> String.downcase() |> String.capitalize() end)
    |> Enum.join("-")
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

        right =
          name
          |> String.replace(~r/^.+?\s*[|\-»:–—]\s*/, "")
          |> String.trim()

        if Regex.match?(~r/^by\b/i, right) do
          name
        else
          if String.contains?(left, ".") do
            left
          else
            name
          end
        end
      else
        name
      end
    end
  end
end
