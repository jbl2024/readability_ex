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
    Floki.filter_out(doc, "script, style, link[rel='preload'][as='script'], noscript")
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
          {"p", attrs, ensure_leading_space(children)}
        end

      other ->
        other
    end)
  end

  defp ensure_leading_space([text | rest]) when is_binary(text) do
    if text == "" or String.starts_with?(text, [" ", "\n", "\t", "\r"]) do
      [text | rest]
    else
      [" " <> text | rest]
    end
  end

  defp ensure_leading_space(children), do: children

  defp has_block_children?(children) when is_list(children) do
    Enum.any?(children, fn
      {tag, _attrs, _kids} -> block_tag?(tag)
      _ -> false
    end)
  end

  defp replace_brbr_with_p(doc) do
    # Convert sequences of <br><br> into <p> blocks, preserving block-level children.
    Floki.traverse_and_update(doc, fn
      {tag, attrs, children} when tag in ["div", "section", "article"] ->
        if has_p_children?(children) do
          {tag, attrs, children}
        else
          new_children = br_children_to_paragraphs(children)
          {tag, attrs, new_children}
        end

      other ->
        other
    end)
  end

  defp has_p_children?(children) when is_list(children) do
    Enum.any?(children, fn
      {"p", _, _} -> true
      _ -> false
    end)
  end

  defp br_children_to_paragraphs(children) when is_list(children) do
    {out, current, _last_br?} =
      Enum.reduce(children, {[], [], false}, fn child, {acc, cur, last_br} ->
        cond do
          match?({"br", _, _}, child) ->
            if last_br do
              {acc ++ maybe_paragraph(cur), [], false}
            else
              {acc, cur, true}
            end

          is_binary(child) ->
            {acc, cur ++ [child], false}

          block_node?(child) ->
            {acc ++ maybe_paragraph(cur) ++ [child], [], false}

          true ->
            {acc, cur ++ [child], false}
        end
      end)

    out ++ maybe_paragraph(current)
  end

  defp block_node?({tag, _attrs, _kids}), do: block_tag?(tag)
  defp block_node?(_), do: false

  defp maybe_paragraph(children) do
    cleaned =
      children
      |> Enum.map(fn
        s when is_binary(s) ->
          if String.trim(s) == "" do
            ""
          else
            s
          end

        x ->
          x
      end)
      |> Enum.reject(&(&1 == ""))

    if cleaned == [], do: [], else: [{"p", [], cleaned}]
  end

  defp block_tag?(tag) do
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
      when tag in ["nav", "footer", "aside", "form", "object", "embed"] ->
        nil

      {tag, attrs, children} ->
        s = attr(attrs, "class") <> " " <> attr(attrs, "id")
        data_component = attr(attrs, "data-component")

        if Regex.match?(
             ~r/\barticle__photo\b|photo--opener|article__photo__image|article__photo__desc|content-head|content-bar|author__|author--article|codefragment|recirc|itemendrow|related-articles-module|most-popular-recircs|teads|caption-credit|post-meta|bloc_signature/i,
             s
           ) or Regex.match?(~r/\btaboola\b/i, s) or data_component == "taboola" or
             String.starts_with?(attr(attrs, "id"), "twttr_") or
             String.starts_with?(attr(attrs, "id"), "trc_") do
          nil
        else
          {tag, attrs, children}
        end

      other ->
        other
    end)
  end

  def remove_unlikely_nodes(node) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} ->
        s = attr(attrs, "class") <> " " <> attr(attrs, "id")

        if s != "" and Regex.match?(Constants.re_unlikely(), s) and
             not Regex.match?(Constants.re_ok_maybe(), s) do
          nil
        else
          {tag, attrs, children}
        end

      other ->
        other
    end)
  end

  def downgrade_h1(node) do
    Floki.traverse_and_update(node, fn
      {"h1", attrs, children} ->
        itemprop = attr(attrs, "itemprop") |> String.downcase()

        if String.contains?(itemprop, "headline") do
          nil
        else
          {"h2", attrs, children}
        end
      other -> other
    end)
  end

  defp should_drop_conditionally?(node) do
    text = Floki.text(node) |> String.trim()
    weight = class_weight(node)
    content_score = content_score(node)

    cond do
      weight + content_score < 0 -> true
      text != "" and Regex.match?(~r/\badvertising\b/i, text) and String.length(text) < 200 and
          ReadabilityEx.Metrics.link_density(node) > 0.2 ->
        true
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
        p_count == 0 and media_count > 1 and tlen < 200 -> true
        p_count > 0 and media_count / p_count > 2.0 and tlen < 1000 -> true
        li_count > p_count and tag_name(node) not in ["ul", "ol"] and tlen < 1000 -> true
        input_count > p_count / 3 -> true
        true -> false
      end
    end
  end

  defp tag_name({tag, _attrs, _children}), do: String.downcase(tag)

  def simplify_nested_elements(node) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} when tag in ["div", "section"] ->
        cond do
          content_wrapper_with_single_child?(attrs, children) ->
            [{_ctag, cattrs, cchildren}] = Enum.filter(children, &match?({_, _, _}, &1))

            if attr(cattrs, "id") == "content-main" do
              {"div", cattrs, cchildren}
            else
              {tag, attrs, cchildren}
            end

          redundant_div_with_p?(tag, attrs, children) ->
            List.first(children)

          true ->
            meaningful_text? = direct_text?(children)
            preserve_wrapper? = preserve_wrapper?(attrs)

            child_structural =
              children
              |> Enum.filter(&match?({_, _, _}, &1))
              |> Enum.filter(fn {ctag, _, _} -> String.downcase(ctag) in ["div", "section"] end)

            if not preserve_wrapper? and not meaningful_text? and length(child_structural) == 1 and
                 only_whitespace_text?(children) do
              {ctag, cattrs, cchildren} = hd(child_structural)
              merged_attrs = merge_attrs(cattrs, attrs)
              {ctag, merged_attrs, cchildren}
            else
              {tag, attrs, children}
            end
        end

      other ->
        other
    end)
  end

  def unwrap_content_main(node) do
    Floki.traverse_and_update(node, fn
      {"div", attrs, children} ->
        if attr(attrs, "id") == "content" do
          case Enum.find(children, fn
                 {"main", cattrs, _} -> attr(cattrs, "id") == "content-main"
                 _ -> false
               end) do
            {"main", cattrs, cchildren} ->
              {"div", cattrs, cchildren}

            _ ->
              {"div", attrs, children}
          end
        else
          {"div", attrs, children}
        end

      other ->
        other
    end)
  end

  defp direct_text?(children) when is_list(children) do
    Enum.any?(children, fn
      s when is_binary(s) -> String.trim(s) != ""
      _ -> false
    end)
  end

  defp direct_text?(_), do: false

  defp only_whitespace_text?(children) when is_list(children) do
    element_count =
      Enum.count(children, fn
        {_, _, _} -> true
        _ -> false
      end)

    text_ok? =
      Enum.all?(children, fn
        s when is_binary(s) -> String.trim(s) == ""
        _ -> true
      end)

    element_count == 1 and text_ok?
  end

  defp only_whitespace_text?(_), do: false

  defp preserve_wrapper?(attrs) do
    id_attr = attr(attrs, "id")
    class_attr = attr(attrs, "class")

    id_attr in ["readability-page-1", "content", "article-content"] or
      String.split(class_attr, ~r/\s+/, trim: true) |> Enum.any?(&(&1 == "page"))
  end

  defp content_wrapper_with_single_child?(attrs, children) do
    attr(attrs, "id") == "content" and only_whitespace_text?(children)
  end

  defp redundant_div_with_p?(tag, attrs, children) do
    tag == "div" and not preserve_wrapper?(attrs) and only_whitespace_text?(children) and
      attrs_redundant?(attrs) and
      case Enum.filter(children, &match?({_, _, _}, &1)) do
        [{"p", _, _}] -> true
        _ -> false
      end
  end

  defp attrs_redundant?(attrs) do
    Enum.all?(attrs, fn {k, _v} ->
      k in ["class", "id", "role"] or String.starts_with?(k, "data-") or
        String.starts_with?(k, "aria-")
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

  def strip_attributes_and_classes(nil, _preserve_classes), do: nil

  def strip_attributes_and_classes(node, preserve_classes) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} ->
        attrs =
          attrs
          |> Enum.reject(fn {k, _} ->
            k in ["style", "align", "bgcolor", "valign", "border", "cellpadding", "cellspacing"]
          end)
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
        if empty_node?(tag, attrs, children) do
          nil
        else
          {tag, attrs, children}
        end

      other ->
        other
    end)
  end

  defp empty_node?(tag, attrs, children) do
    if preserve_wrapper?(attrs) do
      false
    else
      tag = String.downcase(tag)
      text = children |> Floki.text() |> String.trim()

      if text != "" do
        false
      else
        node = {tag, [], children}

        has_media =
          Floki.find(node, "img,video,audio,svg,iframe,object,embed") != []

        if has_media do
          false
        else
          tag in ["p", "div", "section", "span"]
        end
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
        url

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
