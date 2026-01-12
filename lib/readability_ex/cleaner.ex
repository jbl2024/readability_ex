defmodule ReadabilityEx.Cleaner do
  @moduledoc false

  alias ReadabilityEx.Constants

  def unwrap_noscript_images(doc) do
    # Strategy:
    # - remove placeholder <img> without src or tiny data URI
    # - if <noscript> contains exactly one <img> and previous sibling is placeholder <img>,
    #   replace placeholder with that img, merge attributes.
    Floki.traverse_and_update(doc, fn
      {"noscript", _attrs, _children} = ns ->
        imgs = Floki.find(ns, "img")

        case imgs do
          [img] ->
            # We keep noscript for now, swap happens in second pass where we have siblings.
            {"noscript", [{"data-readability-noscript", "1"}], [img]}

          _ ->
            ns
        end

      other ->
        other
    end)
    |> noscript_swap_pass()
  end

  defp noscript_swap_pass(doc) do
    Floki.traverse_and_update(doc, fn
      {tag, attrs, children} ->
        {tag, attrs, swap_children(children)}

      other ->
        other
    end)
  end

  defp swap_children(children) when is_list(children) do
    do_swap(children, [])
    |> Enum.reverse()
  end

  defp swap_children(other), do: other

  defp do_swap([], acc), do: acc

  defp do_swap([child | rest], acc) do
    case {child, List.first(rest)} do
      {{"img", img_attrs, _} = img, {"noscript", ns_attrs, [ns_img]}} ->
        if placeholder_img?(img) and List.keyfind(ns_attrs, "data-readability-noscript", 0) do
          merged = merge_img_attrs(ns_img, img_attrs)
          do_swap(rest |> tl(), [merged | acc])
        else
          do_swap(rest, [child | acc])
        end

      _ ->
        do_swap(rest, [child | acc])
    end
  end

  defp placeholder_img?({"img", attrs, _}) do
    src = attr(attrs, "src")

    cond do
      src == "" -> true
      String.starts_with?(src, "data:") and byte_size(src) < 133 -> true
      true -> false
    end
  end

  defp merge_img_attrs({"img", ns_attrs, ns_children}, placeholder_attrs) do
    merged =
      placeholder_attrs
      |> Enum.reduce(ns_attrs, fn {k, v}, acc ->
        if attr(acc, k) == "" and v != "" do
          List.keystore(acc, k, 0, {k, v})
        else
          acc
        end
      end)

    {"img", merged, ns_children}
  end

  def remove_scripts(doc) do
    Floki.filter_out(doc, "script, style, iframe, link[rel='preload'][as='script'], noscript")
  end

  def prep_document(doc) do
    doc
    |> remove_comments()
    |> replace_font_tags()
    |> replace_brbr_with_p()
    |> remove_redundant_brs()
    |> convert_divs_to_paragraphs()
    |> fix_lazy_images()
  end

  defp replace_font_tags(doc) do
    Floki.traverse_and_update(doc, fn
      {"font", attrs, children} -> {"span", attrs, children}
      other -> other
    end)
  end

  defp remove_redundant_brs(doc) do
    Floki.traverse_and_update(doc, fn
      {tag, attrs, children} when tag in ["div", "section", "article"] ->
        if Enum.any?(children, &match?({"p", _, _}, &1)) do
          new_children =
            Enum.reject(children, fn
              {"br", _, _} -> true
              _ -> false
            end)

          {tag, attrs, new_children}
        else
          {tag, attrs, children}
        end

      other ->
        other
    end)
  end

  def remove_comments(doc) do
    Floki.traverse_and_update(doc, fn
      {:comment, _} -> nil
      {:comment, _, _} -> nil
      other -> other
    end)
  end

  defp convert_divs_to_paragraphs(doc) do
    Floki.traverse_and_update(doc, fn
      {"div", attrs, children} = node ->
        if has_block_children?(children) do
          node
        else
          {"p", attrs, children}
        end

      other ->
        other
    end)
  end

  defp has_block_children?(children) when is_list(children) do
    Enum.any?(children, fn
      {tag, _attrs, _kids} ->
        String.downcase(tag) in [
          "address",
          "article",
          "aside",
          "blockquote",
          "canvas",
          "details",
          "div",
          "dl",
          "fieldset",
          "figcaption",
          "figure",
          "footer",
          "form",
          "h1",
          "h2",
          "h3",
          "h4",
          "h5",
          "h6",
          "header",
          "hgroup",
          "hr",
          "main",
          "menu",
          "nav",
          "ol",
          "p",
          "pre",
          "section",
          "table",
          "ul"
        ]

      _ ->
        false
    end)
  end

  defp replace_brbr_with_p(doc) do
    # Convert sequences of <br><br> into <p> blocks in a pragmatic way.
    # This is a simplified but deterministic transform: split text runs around double BR.
    Floki.traverse_and_update(doc, fn
      {tag, attrs, children} when tag in ["div", "section", "article"] ->
        has_block_children =
          Enum.any?(children, fn
            {ctag, _, _} ->
              String.downcase(ctag) in [
                "p",
                "div",
                "section",
                "article",
                "pre",
                "blockquote",
                "ul",
                "ol",
                "table",
                "h1",
                "h2",
                "h3",
                "h4",
                "h5",
                "h6"
              ]

            _ ->
              false
          end)

        if has_block_children do
          {tag, attrs, children}
        else
          new_children =
            children
            |> normalize_br(children_to_tokens())
            |> tokens_to_paragraph_nodes()

          {tag, attrs, new_children}
        end

      other ->
        other
    end)
  end

  defp children_to_tokens() do
    fn children ->
      Enum.map(children, fn
        {"br", _, _} -> {:br}
        x when is_binary(x) -> {:text, x}
        node -> {:node, node}
      end)
    end
  end

  defp normalize_br(children, mapper) when is_list(children) do
    mapper.(children)
  end

  defp tokens_to_paragraph_nodes(tokens) do
    # Break on consecutive BR
    {paras, current, _last_br?} =
      Enum.reduce(tokens, {[], [], false}, fn t, {ps, cur, last_br} ->
        case t do
          {:br} ->
            if last_br do
              ps = push_para(ps, cur)
              {ps, [], false}
            else
              {ps, cur, true}
            end

          {:text, s} ->
            {ps, cur ++ [s], false}

          {:node, n} ->
            {ps, cur ++ [n], false}
        end
      end)

    paras = push_para(paras, current)

    Enum.flat_map(paras, fn
      [] -> []
      pchildren -> [{"p", [], pchildren}]
    end)
  end

  defp push_para(ps, cur) do
    cleaned =
      cur
      |> Enum.map(fn
        s when is_binary(s) -> String.trim(s)
        x -> x
      end)
      |> Enum.reject(&(&1 == ""))

    if cleaned == [], do: ps, else: ps ++ [cleaned]
  end

  def fix_lazy_images(doc) do
    Floki.traverse_and_update(doc, fn
      {"img", attrs, children} ->
        attrs = promote_lazy_attrs(attrs)
        attrs = cleanup_tiny_data_uri(attrs)
        {"img", attrs, children}

      {"figure", attrs, children} = fig ->
        if Floki.find(fig, "img") == [] do
          url = find_any_image_url_in_attrs(attrs)

          if url do
            {"figure", attrs, children ++ [{"img", [{"src", url}], []}]}
          else
            fig
          end
        else
          fig
        end

      other ->
        other
    end)
  end

  defp promote_lazy_attrs(attrs) do
    src = attr(attrs, "src")
    srcset = attr(attrs, "srcset")

    {attrs, _src} =
      if src == "" or tiny_data_uri?(src) do
        lazy = Enum.find(Constants.lazy_src_attrs(), fn k -> attr(attrs, k) != "" end)

        if lazy,
          do: {List.keystore(attrs, "src", 0, {"src", attr(attrs, lazy)}), attr(attrs, lazy)},
          else: {attrs, src}
      else
        {attrs, src}
      end

    if srcset == "" do
      lazyset =
        Enum.find(["data-srcset", "data-lazy-srcset", "data-src-set"], fn k ->
          attr(attrs, k) != ""
        end)

      if lazyset,
        do: List.keystore(attrs, "srcset", 0, {"srcset", attr(attrs, lazyset)}),
        else: attrs
    else
      attrs
    end
  end

  defp cleanup_tiny_data_uri(attrs) do
    src = attr(attrs, "src")

    if tiny_data_uri?(src) do
      # If any other attr looks like a real image url, drop src and let promoted attr win
      if Enum.any?(attrs, fn {k, v} ->
           k != "src" and Regex.match?(Constants.urlish_image_re(), v)
         end) do
        List.keydelete(attrs, "src", 0)
      else
        attrs
      end
    else
      attrs
    end
  end

  defp tiny_data_uri?(s), do: String.starts_with?(s || "", "data:") and byte_size(s || "") < 133

  defp find_any_image_url_in_attrs(attrs) do
    attrs
    |> Enum.map(fn {_k, v} -> v end)
    |> Enum.find(&Regex.match?(Constants.urlish_image_re(), &1))
  end

  def clean_conditionally(node) do
    # Applied to subtree (div, ul, table, etc.) based on shadiness metrics.
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} = n when tag in ["div", "section", "ul", "ol", "table", "form"] ->
        if should_drop_conditionally?(n) do
          nil
        else
          {tag, attrs, children}
        end

      other ->
        other
    end)
  end

  def remove_semantic_junk(node) do
    Floki.traverse_and_update(node, fn
      {tag, _attrs, _children}
      when tag in ["nav", "footer", "aside", "form", "iframe", "object", "embed"] ->
        nil

      other ->
        other
    end)
  end

  def downgrade_h1(node) do
    Floki.traverse_and_update(node, fn
      {"h1", attrs, children} -> {"h2", attrs, children}
      other -> other
    end)
  end

  defp should_drop_conditionally?(node) do
    text = Floki.text(node) |> String.trim()
    weight = class_weight(node)
    content_score = content_score(node)

    cond do
      weight + content_score < 0 -> true
      text != "" and Regex.match?(Constants.re_ad_words(), text) -> true
      text != "" and Regex.match?(Constants.re_loading_words(), text) -> true
      true -> shady_metrics_drop?(node)
    end
  end

  defp class_weight(node) do
    {tag, attrs, _children} = node
    class = attr(attrs, "class")
    id_attr = attr(attrs, "id")

    base =
      case String.downcase(tag) do
        "div" -> 5
        "pre" -> 3
        "td" -> 3
        "blockquote" -> 3
        "address" -> -3
        "ol" -> -3
        "ul" -> -3
        "dl" -> -3
        "dd" -> -3
        "dt" -> -3
        "li" -> -3
        "form" -> -3
        "h1" -> -5
        "h2" -> -5
        "h3" -> -5
        "h4" -> -5
        "h5" -> -5
        "h6" -> -5
        "th" -> -5
        _ -> 0
      end

    base + ReadabilityEx.Metrics.class_weight(class, id_attr)
  end

  defp content_score(node) do
    text = Floki.text(node)
    comma_segments = text |> String.split(Constants.re_commas()) |> length()
    len_bonus = min(text |> String.length() |> Kernel./(100) |> Float.floor(), 3.0)
    1.0 + comma_segments + len_bonus
  end

  defp shady_metrics_drop?(node) do
    # Metrics similar to spec:
    # - heading density too high
    # - link density high
    # - img vs p, li vs p, etc.
    text = Floki.text(node)
    tlen = String.length(text)

    if tlen == 0 do
      false
    else
      headings_len =
        node
        |> Floki.find("h1,h2,h3,h4,h5,h6")
        |> Floki.text()
        |> String.length()

      heading_ratio = headings_len / max(1, tlen)
      link_density = ReadabilityEx.Metrics.link_density(node)

      p_count = node |> Floki.find("p") |> length()
      img_count = node |> Floki.find("img") |> length()
      svg_count = node |> Floki.find("svg") |> length()
      media_count = img_count + svg_count
      li_count = node |> Floki.find("li") |> length()
      input_count = node |> Floki.find("input") |> length()

      cond do
        heading_ratio > 0.4 -> true
        link_density > 0.2 and tlen < 25 -> true
        link_density > 0.5 -> true
        p_count == 0 and media_count > 1 -> true
        p_count > 0 and media_count / p_count > 2.0 -> true
        li_count > p_count and tag_name(node) not in ["ul", "ol"] -> true
        input_count > p_count / 3 -> true
        true -> false
      end
    end
  end

  defp tag_name({tag, _attrs, _children}), do: String.downcase(tag)

  def simplify_nested_elements(node) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} = n when tag in ["div", "section"] ->
        meaningful_text? = String.trim(Floki.text(n)) != ""

        child_structural =
          children
          |> Enum.filter(&match?({_, _, _}, &1))
          |> Enum.filter(fn {ctag, _, _} -> String.downcase(ctag) in ["div", "section"] end)

        if not meaningful_text? and length(child_structural) == 1 and length(children) == 1 do
          {ctag, cattrs, cchildren} = hd(child_structural)
          merged_attrs = merge_attrs(cattrs, attrs)
          {ctag, merged_attrs, cchildren}
        else
          {tag, attrs, children}
        end

      other ->
        other
    end)
  end

  def flatten_code_tables(node) do
    Floki.traverse_and_update(node, fn
      {"table", _attrs, _children} = table ->
        case Floki.find(table, "pre") do
          [pre] ->
            table_text = table |> Floki.text() |> String.trim()
            pre_text = pre |> Floki.text() |> String.trim()

            if table_text != "" and table_text == pre_text do
              pre
            else
              table
            end

          _ ->
            table
        end

      other ->
        other
    end)
  end

  def strip_attributes_and_classes(node, preserve_classes) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} ->
        attrs =
          attrs
          |> Enum.reject(fn {k, _} -> k in ["style", "align", "bgcolor", "valign", "border"] end)
          |> keep_only_preserved_classes(preserve_classes)

        {tag, attrs, children}

      other ->
        other
    end)
  end

  def replace_javascript_links(node) do
    Floki.traverse_and_update(node, fn
      {"a", attrs, children} ->
        href = attr(attrs, "href") |> String.trim()

        if href == "" or String.match?(href, ~r/^javascript:/i) do
          {"span", [], children}
        else
          {"a", attrs, children}
        end

      other ->
        other
    end)
  end

  def remove_empty_nodes(node) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} ->
        if empty_node?(tag, children) do
          nil
        else
          {tag, attrs, children}
        end

      other ->
        other
    end)
  end

  defp empty_node?(tag, children) do
    tag = String.downcase(tag)
    text = children |> Floki.text() |> String.trim()

    if text != "" do
      false
    else
      has_media =
        Enum.any?(children, fn
          {ctag, _, _} ->
            String.downcase(ctag) in ["img", "video", "audio", "svg", "iframe", "object", "embed"]

          _ ->
            false
        end)

      if has_media do
        false
      else
        tag in ["p", "div", "section", "span"]
      end
    end
  end

  defp keep_only_preserved_classes(attrs, preserve) do
    case List.keyfind(attrs, "class", 0) do
      {"class", v} ->
        kept =
          v
          |> String.split(~r/\s+/, trim: true)
          |> Enum.filter(&MapSet.member?(preserve, &1))

        if kept == [] do
          List.keydelete(attrs, "class", 0)
        else
          List.keystore(attrs, "class", 0, {"class", Enum.join(kept, " ")})
        end

      _ ->
        attrs
    end
  end

  def absolutize_uris(node, base_uri, absolute_fragments?) do
    if base_uri in [nil, ""] do
      node
    else
      base = URI.parse(base_uri)

      Floki.traverse_and_update(node, fn
        {tag, attrs, children} ->
          attrs =
            attrs
            |> abs_attr("href", base, absolute_fragments?)
            |> abs_attr("src", base, true)
            |> abs_attr("poster", base, true)
            |> abs_srcset(base)

          {tag, attrs, children}

        other ->
          other
      end)
    end
  end

  defp abs_attr(attrs, k, base, absolute_fragments?) do
    case List.keyfind(attrs, k, 0) do
      {^k, v} when is_binary(v) and v != "" ->
        if should_absolutize?(k, v, absolute_fragments?) do
          List.keystore(attrs, k, 0, {k, to_abs(v, base)})
        else
          attrs
        end

      _ ->
        attrs
    end
  end

  defp abs_srcset(attrs, base) do
    case List.keyfind(attrs, "srcset", 0) do
      {"srcset", v} when is_binary(v) and v != "" ->
        parts =
          v
          |> String.split(",", trim: true)
          |> Enum.map(fn part ->
            part = String.trim(part)

            case String.split(part, ~r/\s+/, parts: 2, trim: true) do
              [url] -> to_abs(url, base)
              [url, desc] -> to_abs(url, base) <> " " <> desc
            end
          end)

        List.keystore(attrs, "srcset", 0, {"srcset", Enum.join(parts, ", ")})

      _ ->
        attrs
    end
  end

  defp to_abs(url, base) do
    u = URI.parse(url)
    base = if base.path in [nil, ""], do: %{base | path: "/"}, else: base

    cond do
      u.scheme in ["mailto", "tel", "data", "javascript", "about"] ->
        url

      u.scheme in ["http", "https"] ->
        if u.path in [nil, ""] and is_nil(u.query) and is_nil(u.fragment) do
          url <> "/"
        else
          url
        end

      String.starts_with?(url, "//") ->
        (base.scheme || "https") <> ":" <> url

      true ->
        URI.merge(base, u) |> URI.to_string()
    end
  end

  defp should_absolutize?(k, v, absolute_fragments?) do
    cond do
      String.starts_with?(v, "#") and k == "href" ->
        absolute_fragments?

      String.match?(v, ~r/^(mailto|tel|data|javascript|about):/i) ->
        false

      true ->
        true
    end
  end

  defp attr(attrs, k), do: (List.keyfind(attrs, k, 0) || {k, ""}) |> elem(1)

  defp merge_attrs(child_attrs, parent_attrs) do
    parent_attrs
    |> Enum.reduce(child_attrs, fn {k, v}, acc ->
      if attr(acc, k) == "" and v != "" do
        List.keystore(acc, k, 0, {k, v})
      else
        acc
      end
    end)
  end
end
