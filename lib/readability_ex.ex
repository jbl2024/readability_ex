defmodule ReadabilityEx do
  @moduledoc """
  High-fidelity Elixir port of Mozilla Readability.js (behavioral parity).
  - Pre-clean (noscript images, scripts)
  - Metadata (JSON-LD + meta tags)
  - Title refinement
  - Multi-pass sieve with flags
  - Scoring + ancestor propagation
  - Hierarchical promotion (fragmented content)
  - Sibling joining
  - Conditional cleaning + post processing
  """

  alias ReadabilityEx.{Cleaner, Constants, Index, Metadata, Sieve, Title}

  @spec parse(binary(), keyword() | map()) :: {:ok, map()} | {:error, atom()}
  def parse(html, opts \\ []) do
    opts = normalize_opts(opts)
    base_uri = opts[:base_uri] || ""

    doc =
      html
      |> Floki.parse_document!()
      |> Cleaner.unwrap_noscript_images()
      |> Cleaner.remove_scripts()
      |> Cleaner.prep_document()

    {base_uri, absolute_fragments?} = effective_base_uri(doc, base_uri)

    meta = Metadata.extract(doc, html)
    title = Title.get_article_title(doc, meta, opts)

    state = Index.build(doc)

    attempts = [
      run_attempt(
        state,
        doc,
        meta,
        title,
        base_uri,
        absolute_fragments?,
        Constants.flag_all(),
        opts
      ),
      run_attempt(
        state,
        doc,
        meta,
        title,
        base_uri,
        absolute_fragments?,
        Constants.flag_no_strip_unlikelys(),
        opts
      ),
      run_attempt(
        state,
        doc,
        meta,
        title,
        base_uri,
        absolute_fragments?,
        Constants.flag_no_weight_classes(),
        opts
      ),
      run_attempt(
        state,
        doc,
        meta,
        title,
        base_uri,
        absolute_fragments?,
        Constants.flag_no_clean_conditionally(),
        opts
      )
    ]

    best =
      attempts
      |> Enum.reject(&is_nil/1)
      |> Enum.max_by(& &1.length, fn -> nil end)

    case best do
      nil -> {:error, :not_readable}
      result -> {:ok, result}
    end
  end

  defp run_attempt(state, doc, meta, title, base_uri, absolute_fragments?, flags, opts) do
    char_threshold = opts[:char_threshold]

    case Sieve.grab_article(state, doc, flags, base_uri, absolute_fragments?, opts) do
      {:ok, grab} ->
        text = grab.text
        best_ok = String.length(text) >= char_threshold

        %{
          title: title,
          content: grab.content_html,
          textContent: text,
          length: String.length(text),
          excerpt:
            cond do
              is_nil(meta.excerpt) ->
                first_excerpt(grab.content_html, text)

              is_binary(meta.excerpt) and String.trim(meta.excerpt) == "" ->
                first_excerpt(grab.content_html, text)

              true ->
                meta.excerpt
            end
            |> decode_html_entities(),
          byline: meta.byline || grab.byline,
          dir: meta.dir || grab.dir,
          siteName: meta.site_name,
          lang: meta.lang,
          publishedTime: meta.published_time,
          _pass_ok: best_ok
        }

      _ ->
        nil
    end
  end

  defp first_excerpt(content_html, text) do
    with {:ok, doc} <- Floki.parse_fragment(content_html),
         p when not is_nil(p) <-
           doc
           |> Floki.find("p")
           |> Enum.find(fn node -> String.trim(Floki.text(node)) != "" end) do
      p
      |> Floki.text()
      |> String.trim()
    else
      _ ->
        text
        |> String.trim()
        |> full_or_truncated()
    end
  end


  defp full_or_truncated(text) when is_binary(text) do
    if String.length(text) <= 200, do: text, else: String.slice(text, 0, 200)
  end

  defp decode_html_entities(nil), do: nil

  defp decode_html_entities(text) when is_binary(text) do
    Regex.replace(~r/&#x[0-9a-fA-F]+;|&#\d+;/, text, fn match ->
      decode_numeric_entity(match)
    end)
  end

  defp decode_numeric_entity("&#x" <> rest), do: decode_numeric_entity(rest, 16)
  defp decode_numeric_entity("&#X" <> rest), do: decode_numeric_entity(rest, 16)
  defp decode_numeric_entity("&#" <> rest), do: decode_numeric_entity(rest, 10)
  defp decode_numeric_entity(other), do: other

  defp decode_numeric_entity(rest, base) do
    rest = String.trim_trailing(rest, ";")

    case Integer.parse(rest, base) do
      {value, ""} ->
        if valid_codepoint?(value) do
          <<value::utf8>>
        else
          "\uFFFD"
        end

      _ ->
        "&#" <> rest <> ";"
    end
  end

  defp valid_codepoint?(value) do
    value > 0 and value <= 0x10FFFF and not (value in 0xD800..0xDFFF)
  end

  defp normalize_opts(opts) when is_map(opts), do: normalize_opts(Map.to_list(opts))

  defp normalize_opts(opts) when is_list(opts) do
    defaults = [
      char_threshold: 500,
      base_uri: nil,
      preserve_classes: MapSet.new(["page", "caption", "OPEN", "CLOSE", "ORD"])
    ]

    Keyword.merge(defaults, opts)
  end

  defp effective_base_uri(doc, base_uri) do
    base_href =
      doc
      |> Floki.find("base[href]")
      |> Floki.attribute("href")
      |> List.first()

    if base_href && base_href != "" do
      base = URI.parse(base_uri || "")
      href = URI.parse(base_href)
      merged = if base_uri in [nil, ""], do: href, else: URI.merge(base, href)
      {URI.to_string(merged), true}
    else
      {base_uri, false}
    end
  end
end
