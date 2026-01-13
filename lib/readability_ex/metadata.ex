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

  @property_pattern ~r/\s*(article|dc|dcterm|og|twitter)\s*:\s*(author|creator|description|published_time|title|site_name)\s*/i
  @name_pattern ~r/^\s*(?:(dc|dcterm|og|twitter|parsely|weibo:(article|webpage))\s*[-\.:]\s*)?(author|creator|pub-date|description|title|site_name)\s*$/i

  def extract(doc, raw_html) do
    article_title = Title.get_article_title(doc, %{title: ""}, [])
    jsonld = get_jsonld(raw_html, article_title)
    values = get_meta_values(doc)

    %{
      title:
        jsonld[:title] ||
          values["dc:title"] ||
          values["dcterm:title"] ||
          values["og:title"] ||
          values["weibo:article:title"] ||
          values["weibo:webpage:title"] ||
          values["title"] ||
          values["twitter:title"] ||
          values["parsely-title"] ||
          article_title,
      excerpt:
        jsonld[:excerpt] ||
          values["dc:description"] ||
          values["dcterm:description"] ||
          values["og:description"] ||
          values["weibo:article:description"] ||
          values["weibo:webpage:description"] ||
          values["description"] ||
          values["twitter:description"],
      byline:
        jsonld[:byline] ||
          values["dc:creator"] ||
          values["dcterm:creator"] ||
          values["author"] ||
          values["parsely-author"] ||
          article_author(values["article:author"]),
      site_name: jsonld[:site_name] || values["og:site_name"],
      lang: html_attr(doc, "lang"),
      published_time:
        jsonld[:published_time] ||
          values["article:published_time"] ||
          values["parsely-pub-date"] ||
          nil,
      dir: html_attr(doc, "dir")
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

  defp get_meta_values(doc) do
    doc
    |> Floki.find("meta")
    |> Enum.reduce(%{}, fn meta, values ->
      content =
        meta
        |> Floki.attribute("content")
        |> List.first()

      if is_nil(content) or content == "" do
        values
      else
        content = content |> String.trim() |> blank_to_nil()
        property = meta |> Floki.attribute("property") |> List.first()
        name = meta |> Floki.attribute("name") |> List.first()

        if is_nil(content) do
          values
        else
          case property_match(property) do
            {:ok, matched} ->
              Map.put(values, matched, content)

            :error ->
              if name_match?(name) do
                normalized = normalize_meta_name(name)
                Map.put(values, normalized, content)
              else
                values
              end
          end
        end
      end
    end)
  end

  defp property_match(nil), do: :error

  defp property_match(property) do
    case Regex.run(@property_pattern, property) do
      [match | _] ->
        {:ok, match |> String.downcase() |> String.replace(~r/\s+/, "")}

      _ ->
        :error
    end
  end

  defp name_match?(nil), do: false

  defp name_match?(name) do
    Regex.match?(@name_pattern, name)
  end

  defp normalize_meta_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\s+/, "")
    |> String.replace(".", ":")
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
    |> Enum.reduce_while(nil, fn body, _acc ->
      case decode_jsonld(body, article_title) do
        nil -> {:cont, nil}
        jsonld -> {:halt, jsonld}
      end
    end)
    |> case do
      nil -> %{}
      jsonld -> jsonld
    end
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
          byline: extract_author(map["author"]),
          published_time: map["datePublished"] |> blank_to_nil(),
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

  defp article_author(nil), do: nil

  defp article_author(author) when is_binary(author) do
    author = String.trim(author)

    if url?(author) do
      nil
    else
      blank_to_nil(author)
    end
  end

  defp article_author(_), do: nil

  defp url?(nil), do: false

  defp url?(value) when is_binary(value) do
    case URI.parse(value) do
      %URI{scheme: nil} -> false
      %URI{scheme: scheme, host: nil} when scheme in ["http", "https"] -> false
      _ -> true
    end
  end

  defp html_attr(doc, attr) do
    doc
    |> Floki.attribute("html", attr)
    |> List.first()
    |> blank_to_nil()
  end
end
