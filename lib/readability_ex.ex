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

    meta = Metadata.extract(doc, html)
    title = Title.get_article_title(doc, meta, opts)

    state = Index.build(doc)

    attempts = [
      run_attempt(state, doc, meta, title, base_uri, Constants.flag_all(), opts),
      run_attempt(state, doc, meta, title, base_uri, Constants.flag_no_strip_unlikelys(), opts),
      run_attempt(
        state,
        doc,
        meta,
        title,
        base_uri,
        Constants.flag_only_clean_conditionally(),
        opts
      ),
      run_attempt(state, doc, meta, title, base_uri, 0, opts)
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

  defp run_attempt(state, doc, meta, title, base_uri, flags, opts) do
    char_threshold = opts[:char_threshold]

    case Sieve.grab_article(state, doc, flags, base_uri, opts) do
      {:ok, grab} ->
        text = grab.text
        best_ok = String.length(text) >= char_threshold

        %{
          title: title,
          content: grab.content_html,
          textContent: text,
          length: String.length(text),
          excerpt: meta.excerpt || first_excerpt(text),
          byline: meta.byline || grab.byline,
          dir: meta.dir || grab.dir || "ltr",
          siteName: meta.site_name,
          lang: meta.lang,
          publishedTime: meta.published_time,
          _pass_ok: best_ok
        }

      _ ->
        nil
    end
  end

  defp first_excerpt(text) do
    text
    |> String.trim()
    |> String.slice(0, 200)
  end

  defp normalize_opts(opts) when is_map(opts), do: normalize_opts(Map.to_list(opts))

  defp normalize_opts(opts) when is_list(opts) do
    defaults = [
      char_threshold: 500,
      base_uri: nil,
      preserve_classes: MapSet.new(["page"])
    ]

    Keyword.merge(defaults, opts)
  end
end
