defmodule ReadabilityEx.Cleaner do
  @moduledoc false

  alias ReadabilityEx.{Constants, Metrics}

  @phrasing_elems MapSet.new([
                    "ABBR",
                    "AUDIO",
                    "B",
                    "BDO",
                    "BR",
                    "BUTTON",
                    "CITE",
                    "CODE",
                    "DATA",
                    "DATALIST",
                    "DFN",
                    "EM",
                    "EMBED",
                    "I",
                    "IMG",
                    "INPUT",
                    "KBD",
                    "LABEL",
                    "MARK",
                    "MATH",
                    "METER",
                    "NOSCRIPT",
                    "OBJECT",
                    "OUTPUT",
                    "PROGRESS",
                    "Q",
                    "RUBY",
                    "SAMP",
                    "SCRIPT",
                    "SELECT",
                    "SMALL",
                    "SPAN",
                    "STRONG",
                    "SUB",
                    "SUP",
                    "TEXTAREA",
                    "TIME",
                    "VAR",
                    "WBR"
                  ])

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
    |> normalize_text_nodes()
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
      {:comment, _} -> ""
      {:comment, _, _} -> ""
      other -> other
    end)
  end

  defp normalize_text_nodes(doc) do
    Floki.traverse_and_update(doc, fn
      {tag, attrs, children} ->
        {tag, attrs, merge_text_children(children)}

      other ->
        other
    end)
  end

  defp merge_text_children(children) when is_list(children) do
    children
    |> Enum.reduce([], fn
      child, [prev | rest] when is_binary(child) and is_binary(prev) ->
        [join_text(prev, child) | rest]

      child, acc ->
        [child | acc]
    end)
    |> Enum.reverse()
  end

  defp merge_text_children(other), do: other

  defp join_text(prev, next) do
    cond do
      prev == "" ->
        next

      next == "" ->
        prev

      String.match?(prev, ~r/\s\z/u) ->
        prev <> next

      String.match?(next, ~r/\A\s/u) ->
        prev <> next

      String.match?(prev, ~r/[[:alpha:]]\z/u) and String.match?(next, ~r/\A[[:digit:]]/u) ->
        prev <> next

      String.match?(prev, ~r/[[:alpha:]]\z/u) and String.match?(next, ~r/\A[[:alpha:]]/u) ->
        second_char = String.at(next, 1)

        if String.match?(next, ~r/\A[[:lower:]]/u) and
             (String.length(next) == 1 or
                (second_char && not String.match?(second_char, ~r/[[:alpha:]]/u))) do
          prev <> next
        else
          prev <> " " <> next
        end

      String.match?(prev, ~r/[[:alnum:]]\z/u) and String.match?(next, ~r/\A[[:alnum:]]/u) ->
        prev <> " " <> next

      String.match?(prev, ~r/[[:punct:]]\z/u) and String.match?(next, ~r/\A[[:alnum:]]/u) ->
        prev <> " " <> next

      true ->
        prev <> next
    end
  end

  defp convert_divs_to_paragraphs(doc) do
    Floki.traverse_and_update(doc, fn
      {"div", attrs, children} ->
        children = wrap_phrasing_children(children)
        node = {"div", attrs, children}

        cond do
          (single_p_child = single_p_child(children)) && Metrics.link_density(node) < 0.25 ->
            single_p_child

          single_heading_child?(children) ->
            {"p", attrs, children}

          has_block_children?(children) ->
            node

          true ->
            {"p", attrs, children}
        end

      other ->
        other
    end)
  end

  defp has_block_children?(children) when is_list(children) do
    Enum.any?(children, fn
      {tag, _attrs, _kids} -> block_tag?(tag)
      _ -> false
    end)
  end

  defp wrap_phrasing_children(children) when is_list(children) do
    {acc, current} =
      Enum.reduce(children, {[], []}, fn child, {acc, cur} ->
        if phrasing_content?(child) do
          {acc, cur ++ [child]}
        else
          acc = acc ++ wrap_phrasing_group(cur)
          {acc ++ [child], []}
        end
      end)

    acc ++ wrap_phrasing_group(current)
  end

  defp wrap_phrasing_children(children), do: children

  defp wrap_phrasing_group(children) do
    trimmed =
      children
      |> trim_leading_whitespace()
      |> trim_trailing_whitespace()

    if trimmed == [] do
      []
    else
      [{"p", [], trimmed}]
    end
  end

  defp trim_leading_whitespace([head | rest]) when is_binary(head) do
    if String.trim(head) == "" do
      trim_leading_whitespace(rest)
    else
      [head | rest]
    end
  end

  defp trim_leading_whitespace(children), do: children

  defp trim_trailing_whitespace(children) when is_list(children) do
    children
    |> Enum.reverse()
    |> trim_leading_whitespace()
    |> Enum.reverse()
  end

  defp trim_trailing_whitespace(children), do: children

  defp element_children({_, _, children}) do
    Enum.filter(children, &match?({_, _, _}, &1))
  end

  defp single_heading_child?(children) when is_list(children) do
    case Enum.filter(children, &match?({_, _, _}, &1)) do
      [{tag, _attrs, _kids}] -> String.downcase(tag) in ["h1", "h2", "h3", "h4", "h5", "h6"]
      _ -> false
    end
  end

  defp single_p_child(children) when is_list(children) do
    elements = Enum.filter(children, &match?({_, _, _}, &1))

    case elements do
      [{"p", _attrs, _kids} = p] ->
        text_ok? =
          Enum.all?(children, fn
            s when is_binary(s) -> String.trim(s) == ""
            _ -> true
          end)

        if text_ok?, do: p, else: nil

      _ ->
        nil
    end
  end

  defp single_p_child(_children), do: nil

  defp replace_brbr_with_p(doc) do
    # Convert sequences of <br><br> into <p> blocks, preserving block-level children.
    Floki.traverse_and_update(doc, fn
      {tag, attrs, children} when tag in ["div", "section", "article"] ->
        if has_p_children?(children) or not has_double_br?(children) do
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
    {out, current, pending_br?} =
      Enum.reduce(children, {[], [], false}, fn child, {acc, cur, pending_br} ->
        cond do
          match?({"br", _, _}, child) ->
            if pending_br do
              {acc ++ maybe_paragraph(cur), [], false}
            else
              {acc, cur, true}
            end

          is_binary(child) ->
            if pending_br do
              child =
                if cur == [] and not String.starts_with?(child, [" ", "\n", "\t", "\r"]) do
                  " " <> child
                else
                  child
                end

              cur =
                if cur == [] do
                  cur
                else
                  cur ++ [{"br", [], []}]
                end

              {acc, cur ++ [child], false}
            else
              {acc, cur ++ [child], false}
            end

          block_node?(child) ->
            cur = if pending_br, do: cur ++ [{"br", [], []}], else: cur
            {acc ++ maybe_paragraph(cur) ++ [child], [], false}

          true ->
            cur = if pending_br, do: cur ++ [{"br", [], []}], else: cur
            {acc, cur ++ [child], false}
        end
      end)

    current = if pending_br?, do: current ++ [{"br", [], []}], else: current
    out ++ maybe_paragraph(current)
  end

  defp block_node?({tag, _attrs, _kids}), do: block_tag?(tag)
  defp block_node?(_), do: false

  defp has_double_br?(children) when is_list(children) do
    {found, _last_br?} =
      Enum.reduce(children, {false, false}, fn child, {found, last_br?} ->
        cond do
          found ->
            {true, last_br?}

          match?({"br", _, _}, child) ->
            if last_br?, do: {true, true}, else: {false, true}

          is_binary(child) and String.trim(child) == "" ->
            {false, last_br?}

          true ->
            {false, false}
        end
      end)

    found
  end

  defp has_double_br?(_), do: false

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
      |> drop_edge_brs()

    if cleaned == [], do: [], else: [{"p", [], cleaned}]
  end

  defp drop_edge_brs(children) do
    children
    |> drop_leading_brs()
    |> drop_trailing_brs()
  end

  defp drop_leading_brs([{"br", _, _} | rest]), do: drop_leading_brs(rest)
  defp drop_leading_brs(children), do: children

  defp drop_trailing_brs(children) do
    children
    |> Enum.reverse()
    |> drop_leading_brs()
    |> Enum.reverse()
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
      "meta",
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

  def clean_styles(node) do
    clean_styles_node(node)
  end

  defp clean_styles_node(nil), do: nil

  defp clean_styles_node({tag, attrs, children}) do
    if String.downcase(tag) == "svg" do
      {tag, attrs, children}
    else
      attrs =
        attrs
        |> Enum.reject(fn {k, _} -> k in presentational_attrs() end)
        |> drop_deprecated_size_attrs(tag)

      cleaned_children =
        children
        |> Enum.map(fn
          {ctag, cattrs, cchildren} -> clean_styles_node({ctag, cattrs, cchildren})
          other -> other
        end)

      {tag, attrs, cleaned_children}
    end
  end

  defp clean_styles_node(other), do: other

  def mark_data_tables(root) do
    mark_node(root, false, false)
  end

  defp mark_node({tag, attrs, children} = node, inside_data_table?, inside_table?) do
    tag = String.downcase(tag)
    data_table? = tag == "table" and data_table?(node)

    attrs =
      attrs
      |> maybe_put_attr("data-readability-datatable", data_table? && "1")
      |> maybe_put_attr("data-readability-datatable", (tag == "table" and not data_table?) && "0")
      |> maybe_put_attr("data-readability-inside-datatable", inside_data_table? && "1")
      |> maybe_put_attr("data-readability-inside-table", inside_table? && "1")

    children =
      children
      |> Enum.map(fn
        {ctag, cattrs, cchildren} ->
          mark_node(
            {ctag, cattrs, cchildren},
            inside_data_table? or data_table?,
            inside_table? or tag == "table"
          )

        other ->
          other
      end)

    {tag, attrs, children}
  end

  defp mark_node(other, _inside_data, _inside_table), do: other

  defp maybe_put_attr(attrs, _k, false), do: attrs
  defp maybe_put_attr(attrs, _k, nil), do: attrs

  defp maybe_put_attr(attrs, k, v) do
    List.keystore(attrs, k, 0, {k, v})
  end

  defp data_table?({_, attrs, children} = node) do
    role = attr(attrs, "role")

    cond do
      role == "presentation" ->
        false

      attr(attrs, "datatable") == "0" ->
        false

      attr(attrs, "summary") != "" ->
        true

      has_caption?(children) ->
        true

      has_data_table_descendant?(node) ->
        true

      has_nested_table?(node) ->
        false

      true ->
        size = row_and_column_count(node)

        cond do
          size.columns == 1 or size.rows == 1 ->
            false

          size.rows >= 10 or size.columns > 4 ->
            true

          true ->
            size.rows * size.columns > 10
        end
    end
  end

  defp has_caption?(children) do
    Enum.any?(children, fn
      {"caption", _attrs, cchildren} ->
        Enum.any?(cchildren, fn
          s when is_binary(s) -> String.trim(s) != ""
          {_, _, _} -> true
          _ -> false
        end)

      _ ->
        false
    end)
  end

  defp has_data_table_descendant?(node) do
    Floki.find(node, "col,colgroup,tfoot,thead,th") != []
  end

  defp has_nested_table?(node) do
    Floki.find(node, "table table") != []
  end

  defp row_and_column_count(node) do
    rows =
      node
      |> Floki.find("tr")

    Enum.reduce(rows, %{rows: 0, columns: 0}, fn row, acc ->
      rowspan =
        row
        |> Floki.attribute("rowspan")
        |> List.first()
        |> parse_int(0)

      rows_count = acc.rows + max(rowspan, 1)

      columns_in_row =
        row
        |> Floki.find("td")
        |> Enum.reduce(0, fn cell, sum ->
          colspan =
            cell
            |> Floki.attribute("colspan")
            |> List.first()
            |> parse_int(0)

          sum + max(colspan, 1)
        end)

      %{rows: rows_count, columns: max(acc.columns, columns_in_row)}
    end)
  end

  defp parse_int(nil, default), do: default

  defp parse_int(value, default) do
    case Integer.parse(value) do
      {num, _} -> num
      _ -> default
    end
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
    node
    |> clean_conditionally_tag("form")
    |> clean_conditionally_tag("fieldset")
    |> clean_conditionally_tag("table")
    |> clean_conditionally_tag("ul")
    |> clean_conditionally_tag("div")
  end

  defp clean_conditionally_tag(node, tag) do
    clean_conditionally_tag(
      node,
      tag,
      %{in_code: false, in_figure: false, in_data_table: false},
      true
    )
  end

  defp clean_conditionally_tag({tag, attrs, children}, tag_name, ctx, is_root?) do
    tag_lower = String.downcase(tag)
    in_code = ctx.in_code or tag_lower == "code"
    in_figure = ctx.in_figure or tag_lower == "figure"
    in_data_table = ctx.in_data_table or attr(attrs, "data-readability-datatable") == "1"

    remove? =
      tag_lower == tag_name and
        not is_root? and
        should_remove_conditionally?({tag_lower, attrs, children}, tag_name, %{
          in_code: in_code,
          in_figure: in_figure,
          in_data_table: in_data_table
        })

    if remove? do
      nil
    else
      cleaned_children =
        children
        |> Enum.map(fn
          {ctag, cattrs, cchildren} ->
            clean_conditionally_tag(
              {ctag, cattrs, cchildren},
              tag_name,
              %{
                in_code: in_code,
                in_figure: in_figure,
                in_data_table: in_data_table
              },
              false
            )

          other ->
            other
        end)
        |> Enum.reject(&is_nil/1)

      {tag, attrs, cleaned_children}
    end
  end

  defp clean_conditionally_tag(other, _tag, _ctx, _is_root?), do: other

  defp should_remove_conditionally?({tag, attrs, _children} = node, tag_name, ctx) do
    tag = String.downcase(tag)
    is_list = tag in ["ul", "ol"] or list_content?(node)

    cond do
      tag_name == "table" and data_table_attr?(attrs) ->
        false

      ctx.in_data_table ->
        false

      ctx.in_code ->
        false

      contains_data_table?(node) ->
        false

      true ->
        weight = Metrics.class_weight(attr(attrs, "class"), attr(attrs, "id"))
        content_score = 0

        if weight + content_score < 0 do
          true
        else
          if char_count(node, ",") < 10 do
            p = count_tag(node, "p")
            img = count_tag(node, "img")
            li = count_tag(node, "li") - 100
            input = count_tag(node, "input")
            heading_density = text_density(node, ["h1", "h2", "h3", "h4", "h5", "h6"])

            {embed_count, allowed_embed?} = count_embeds(node)

            if allowed_embed? do
              false
            else
              inner_text = inner_text(node, true)

              cond do
                Regex.match?(Constants.re_ad_words(), inner_text) ->
                  true

                Regex.match?(Constants.re_loading_words(), inner_text) ->
                  true

                true ->
                  content_length = String.length(inner_text)
                  link_density = Metrics.link_density(node)
                  text_density = text_density(node, textish_tags())
                  is_figure_child = ctx.in_figure
                  link_density_modifier = 0.0

                  have_to_remove =
                    (not is_figure_child and img > 1 and safe_ratio(p, img) < 0.5) or
                      (not is_list and li > p) or
                      (input > floor(p / 3)) or
                      (not is_list and not is_figure_child and heading_density < 0.9 and
                         content_length < 25 and (img == 0 or img > 2) and link_density > 0) or
                      (not is_list and weight < 25 and
                         link_density > 0.2 + link_density_modifier) or
                      (weight >= 25 and link_density > 0.5 + link_density_modifier) or
                      ((embed_count == 1 and content_length < 75) or embed_count > 1) or
                      (img == 0 and text_density == 0)

                  if is_list and have_to_remove do
                    keep_list_candidate?(node, img)
                  else
                    have_to_remove
                  end
              end
            end
          else
            false
          end
        end
    end
  end

  defp data_table_attr?(attrs) do
    attr(attrs, "data-readability-datatable") == "1"
  end

  defp contains_data_table?(node) do
    Floki.find(node, "table[data-readability-datatable='1']") != []
  end

  defp list_content?(node) do
    inner = inner_text(node, true)

    if inner == "" do
      false
    else
      list_length =
        node
        |> Floki.find("ul,ol")
        |> Enum.reduce(0, fn list, acc -> acc + String.length(inner_text(list, true)) end)

      list_length / String.length(inner) > 0.9
    end
  end

  defp keep_list_candidate?(node, img_count) do
    element_children = element_children(node)

    if Enum.any?(element_children, fn {_tag, _attrs, children} ->
         length(Enum.filter(children, &match?({_, _, _}, &1))) > 1
       end) do
      true
    else
      li_count = node |> Floki.find("li") |> length()
      img_count != li_count
    end
  end

  defp char_count(node, char) do
    inner_text(node, true)
    |> String.split(char)
    |> length()
    |> Kernel.-(1)
  end

  defp count_tag(node, tag) do
    node |> Floki.find(tag) |> length()
  end

  defp text_density(node, tags) do
    total = inner_text(node, true)
    total_len = String.length(total)

    if total_len == 0 do
      0.0
    else
      child_len =
        node
        |> Floki.find(Enum.join(tags, ","))
        |> Enum.reduce(0, fn child, acc ->
          acc + String.length(inner_text(child, true))
        end)

      child_len / total_len
    end
  end

  defp textish_tags do
    ["span", "li", "td", "blockquote", "dl", "div", "img", "ol", "p", "pre", "table", "ul"]
  end

  defp inner_text(node, normalize_spaces) do
    text = Floki.text(node) |> String.trim()

    if normalize_spaces do
      Regex.replace(~r/\s+/, text, " ")
    else
      text
    end
  end

  defp safe_ratio(num, denom) do
    if denom == 0 do
      0.0
    else
      num / denom
    end
  end

  defp count_embeds(node) do
    embeds = Floki.find(node, "object,embed,iframe")

    Enum.reduce(embeds, {0, false}, fn {embed_tag, embed_attrs, embed_children}, {count, allowed?} ->
      if allowed? do
        {count, allowed?}
      else
        allowed_embed? =
          Enum.any?(embed_attrs, fn {_k, v} ->
            Regex.match?(Constants.allowed_video_re(), v)
          end) or
            (String.downcase(embed_tag) == "object" and
               Regex.match?(
                 Constants.allowed_video_re(),
                 Floki.raw_html({embed_tag, embed_attrs, embed_children})
               ))

        if allowed_embed? do
          {count, true}
        else
          {count + 1, false}
        end
      end
    end)
  end

  def clean_headers(node) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, _children} = header when tag in ["h1", "h2"] ->
        class = attr(attrs, "class")
        id_attr = attr(attrs, "id")

        if Metrics.class_weight(class, id_attr) < 0 do
          nil
        else
          header
        end

      other ->
        other
    end)
  end

  def clean_share_elements(node, threshold) do
    case node do
      {tag, attrs, children} ->
        cleaned_children =
          children
          |> Enum.map(fn
            {ctag, cattrs, cchildren} ->
              clean_share_node({ctag, cattrs, cchildren}, threshold)

            other ->
              other
          end)
          |> Enum.reject(&is_nil/1)

        {tag, attrs, cleaned_children}

      other ->
        other
    end
  end

  defp clean_share_node({tag, attrs, children}, threshold) do
    match_string = attr(attrs, "class") <> " " <> attr(attrs, "id")

    if Regex.match?(Constants.re_share_elements(), match_string) and
         String.length(String.trim(Floki.text({tag, attrs, children}))) < threshold do
      nil
    else
      cleaned_children =
        children
        |> Enum.map(fn
          {ctag, cattrs, cchildren} ->
            clean_share_node({ctag, cattrs, cchildren}, threshold)

          other ->
            other
        end)
        |> Enum.reject(&is_nil/1)

      {tag, attrs, cleaned_children}
    end
  end

  defp clean_share_node(other, _threshold), do: other

  def remove_title_headers(node, title) do
    title = String.trim(title || "")

    if title == "" do
      node
    else
      {node, _removed?} = remove_title_header_node(node, title, false)
      node
    end
  end

  defp remove_title_header_node({tag, attrs, children} = node, title, removed?) do
    if removed? do
      {node, removed?}
    else
      cond do
        tag in ["h1", "h2"] and text_similarity(title, Floki.text(node)) > 0.75 ->
          {nil, true}

        true ->
          {new_children, removed?} = remove_title_header_children(children, title, removed?)
          {{tag, attrs, new_children}, removed?}
      end
    end
  end

  defp remove_title_header_node(other, _title, removed?), do: {other, removed?}

  defp remove_title_header_children(children, title, removed?) when is_list(children) do
    Enum.reduce(children, {[], removed?}, fn child, {acc, removed_acc?} ->
      {new_child, removed_acc?} = remove_title_header_node(child, title, removed_acc?)

      if is_nil(new_child) do
        {acc, removed_acc?}
      else
        {[new_child | acc], removed_acc?}
      end
    end)
    |> then(fn {acc, removed?} -> {Enum.reverse(acc), removed?} end)
  end

  defp remove_title_header_children(children, _title, removed?), do: {children, removed?}

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
    |> String.downcase()
    |> String.split(~r/\W+/u, trim: true)
  end

  def remove_semantic_junk(node) do
    Floki.traverse_and_update(node, fn
      {tag, _attrs, _children}
      when tag in ["nav", "footer", "aside", "form", "object", "embed"] ->
        nil

      {"div", attrs, children} ->
        id_attr = attr(attrs, "id")

        if String.starts_with?(id_attr, "FlexAd") do
          maybe_continue_link(children)
        else
          remove_semantic_junk_node({"div", attrs, children})
        end

      {tag, attrs, children} ->
        remove_semantic_junk_node({tag, attrs, children})

      other ->
        other
    end)
  end

  def remove_byline_nodes(node) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} = n ->
        match_string = attr(attrs, "class") <> " " <> attr(attrs, "id")
        rel = attr(attrs, "rel") |> String.downcase()
        itemprop = attr(attrs, "itemprop") |> String.downcase()
        byline_length = n |> Floki.text() |> String.trim() |> String.length()

        if (rel == "author" or String.contains?(itemprop, "author") or
              Regex.match?(Constants.re_byline(), match_string)) and byline_length > 0 and
             byline_length < 100 do
          nil
        else
          {tag, attrs, children}
        end

      other ->
        other
    end)
  end

  def wrap_continue_links(node) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} when tag in ["div", "section", "article", "main"] ->
        {tag, attrs, wrap_continue_children(children)}

      other ->
        other
    end)
  end

  defp wrap_continue_children(children) when is_list(children) do
    Enum.flat_map(children, fn
      {"a", _attrs, _children} = a ->
        if continue_link?(a) do
          [{"p", [], [a]}]
        else
          [a]
        end

      child ->
        [child]
    end)
  end

  defp wrap_continue_children(other), do: other

  defp continue_link?(node) do
    href = Floki.attribute(node, "href") |> List.first() |> to_string()
    text = Floki.text(node) |> String.trim()

    (String.starts_with?(href, "#story-continues") or href == "#whats-next") and
      Regex.match?(~r/^Continue reading/i, text)
  end

  defp remove_semantic_junk_node({tag, attrs, children}) do
    s = attr(attrs, "class") <> " " <> attr(attrs, "id")
    id_attr = attr(attrs, "id")
    data_component = attr(attrs, "data-component")
    data_testid = attr(attrs, "data-testid") |> String.downcase()
    itemprop = attr(attrs, "itemprop") |> String.downcase()
    story_body? = Regex.match?(~r/\bstory-body\b/i, s)

    if Regex.match?(
         ~r/\barticle__photo\b|photo--opener|article__photo__image|article__photo__desc|content-head|content-bar|author__|author--article|codefragment|recirc|itemendrow|related-articles-module|most-popular-recircs|teads|caption-credit|post-meta|bloc_signature|banner-headline|breadcrumbs|authors-container|modal|dealbook-branding/i,
         s
       ) or Regex.match?(~r/\btaboola\b/i, s) or
         Regex.match?(
           ~r/\bstory-meta\b|\bstory-header\b|\bstory-ad\b|\bsharetools?\b|\bsharetool\b|\bad-placeholder\b|\breader-satisfaction\b|\bfeedback\b|\bsurvey\b|\bmarginalia\b/i,
           s
         ) or
         (Regex.match?(~r/\bsupplemental\b/i, s) and not story_body?) or
         data_component == "taboola" or
         (tag == "div" and
            Regex.match?(
              ~r/\bmedia-container\b|\bimage-wrapper\b|\bimage-carousel\b|\bcarousel\b/i,
              s
            )) or
         (tag == "button" and
            (Regex.match?(~r/\bcopy\b/i, s) or
               Regex.match?(~r/\bcopy\b/i, Floki.text({tag, attrs, children})))) or
         (tag == "a" and
            String.contains?(attr(attrs, "href"), "module=RelatedLinks")) or
         data_testid == "share-tools" or
         (itemprop != "" and String.contains?(itemprop, "author") and tag in ["p", "span"]) or
         id_attr == "bottom-wrapper" or
         String.starts_with?(id_attr, "twttr_") or
         String.starts_with?(id_attr, "trc_") or
         (id_attr != "" and Regex.match?(~r/^g-.*-chart/i, id_attr)) or
         String.starts_with?(id_attr, "story-ad-") or
         id_attr in [
           "story-meta",
           "story-header",
           "sharetools-story-meta-footer",
           "sharetools-masthead"
         ] do
      nil
    else
      {tag, attrs, children}
    end
  end

  defp maybe_continue_link(children) do
    link =
      children
      |> Floki.find("a")
      |> Enum.find(fn a ->
        href = Floki.attribute(a, "href") |> List.first() |> to_string()
        text = Floki.text(a) |> String.trim()

        String.starts_with?(href, "#story-continues") and
          Regex.match?(~r/^Continue reading/i, text)
      end)

    if link do
      {"p", [], [link]}
    else
      nil
    end
  end

  def remove_unlikely_nodes(node) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} ->
        s = attr(attrs, "class") <> " " <> attr(attrs, "id")

        if s != "" and Regex.match?(Constants.re_unlikely(), s) and
             not Regex.match?(Constants.re_ok_maybe(), s) and
             not keep_unlikely_media?(tag, attrs, children) do
          nil
        else
          {tag, attrs, children}
        end

      other ->
        other
    end)
  end

  defp keep_unlikely_media?(tag, attrs, children) do
    tag = String.downcase(tag)
    itemprop = attr(attrs, "itemprop") |> String.downcase()

    tag in ["figure", "img", "picture", "video"] or
      String.contains?(itemprop, "associatedmedia") or
      media_wrapper_only?(children)
  end

  defp media_wrapper_only?(children) when is_list(children) do
    elements = Enum.filter(children, &match?({_, _, _}, &1))

    text_ok? =
      Enum.all?(children, fn
        s when is_binary(s) -> String.trim(s) == ""
        _ -> true
      end)

    allowed_tags =
      MapSet.new(["figure", "img", "picture", "video", "figcaption", "source", "span"])

    text_ok? and elements != [] and
      Enum.all?(elements, fn {ctag, _, _} ->
        MapSet.member?(allowed_tags, String.downcase(ctag))
      end) and
      (contains_tag?(elements, "img") or contains_tag?(elements, "video") or
         contains_tag?(elements, "picture") or contains_tag?(elements, "figure"))
  end

  defp media_wrapper_only?(_children), do: false

  def downgrade_h1(node) do
    Floki.traverse_and_update(node, fn
      {"h1", attrs, children} ->
        {"h2", attrs, children}

      other ->
        other
    end)
  end

  def simplify_nested_elements(node) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} when tag in ["div", "section"] ->
        cond do
          attr(attrs, "data-testid") == "photoviewer-children" and
              Enum.count(children, &match?({_, _, _}, &1)) == 1 ->
            Enum.find(children, &match?({_, _, _}, &1))

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
        [{"p", _pattrs, pchildren}] ->
          p_text = Floki.text({"p", [], pchildren}) |> String.trim()

          unwrap_wrapper? =
            text_container_wrapper?(attrs) or
              css_wrapper_with_media?(attrs, pchildren) or
              print_edition_paragraph?(p_text)

          not Enum.any?(pchildren, fn
            {ctag, _, _} -> String.downcase(ctag) in ["h1", "h2", "h3", "h4", "h5", "h6"]
            _ -> false
          end) and p_text != "" and unwrap_wrapper? and not keep_bio_wrapper?(attrs, p_text)

        _ ->
          false
      end
  end

  defp attrs_redundant?(attrs) do
    Enum.all?(attrs, fn {k, _v} ->
      k in ["class", "id", "role"] or String.starts_with?(k, "data-") or
        String.starts_with?(k, "aria-")
    end)
  end

  defp text_container_wrapper?(attrs) do
    class = attr(attrs, "class")
    id_attr = attr(attrs, "id")

    (class == "" and id_attr == "") or
      Regex.match?(~r/\b(text|parbase|content)\b/i, class) or
      Regex.match?(~r/\b(content|body)\b/i, id_attr)
  end

  defp css_wrapper_with_media?(attrs, children) do
    class = attr(attrs, "class")

    String.starts_with?(class, "css-") and
      contains_tag?(children, "img")
  end

  defp contains_tag?(children, tag) when is_list(children) do
    Enum.any?(children, fn
      {^tag, _attrs, _kids} -> true
      {_ctag, _cattrs, kids} -> contains_tag?(kids, tag)
      _ -> false
    end)
  end

  defp contains_tag?(_children, _tag), do: false

  defp print_edition_paragraph?(text) do
    String.starts_with?(text, "A version of this article appears in print")
  end

  defp keep_bio_wrapper?(attrs, text) do
    attr(attrs, "class") == "" and attr(attrs, "id") == "" and
      Regex.match?(~r/^[A-Z][^,]+ is a /, text)
  end

  def flatten_tables(node) do
    Floki.traverse_and_update(node, fn
      {"table", _attrs, _children} = table ->
        case single_cell_table?(table) do
          {:ok, cell} ->
            if all_phrasing?(cell) do
              set_node_tag(cell, "p")
            else
              set_node_tag(cell, "div")
            end

          :error ->
            flatten_code_table(table)
        end

      other ->
        other
    end)
  end

  defp flatten_code_table(table) do
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
  end

  defp single_cell_table?(table) do
    tbody =
      if has_single_tag_inside_element?(table, "tbody") do
        {_tag, _attrs, [child]} = table
        child
      else
        table
      end

    with true <- has_single_tag_inside_element?(tbody, "tr"),
         {"tr", _tr_attrs, _tr_children} = row <- first_element_child(tbody),
         true <- has_single_tag_inside_element?(row, "td"),
         {"td", _td_attrs, _td_children} = cell <- first_element_child(row) do
      {:ok, cell}
    else
      _ -> :error
    end
  end

  defp has_single_tag_inside_element?({_tag, _attrs, children}, wanted_tag) do
    elements = Enum.filter(children, &match?({_, _, _}, &1))

    case elements do
      [{child_tag, _cattrs, _}] ->
        String.downcase(child_tag) == wanted_tag and
          not has_text_content?(children)

      _ ->
        false
    end
  end

  defp has_single_tag_inside_element?(_, _), do: false

  defp first_element_child({_, _, children}) do
    Enum.find(children, &match?({_, _, _}, &1))
  end

  defp has_text_content?(children) do
    Enum.any?(children, fn
      s when is_binary(s) -> String.trim(s) != ""
      _ -> false
    end)
  end

  defp all_phrasing?({_, _, children}) do
    Enum.all?(children, &phrasing_content?/1)
  end

  defp all_phrasing?(_), do: false

  defp phrasing_content?(text) when is_binary(text), do: true

  defp phrasing_content?({tag, _attrs, children}) do
    tag = String.upcase(tag)

    cond do
      MapSet.member?(@phrasing_elems, tag) ->
        true

      tag in ["A", "DEL", "INS"] ->
        Enum.all?(children, &phrasing_content?/1)

      true ->
        false
    end
  end

  defp set_node_tag({_, attrs, children}, new_tag) do
    {new_tag, attrs, children}
  end

  def strip_attributes_and_classes(nil, _preserve_classes), do: nil

  def strip_attributes_and_classes(node, preserve_classes) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} ->
        attrs =
          attrs
          |> Enum.reject(fn {k, _} ->
            k in [
              "style",
              "align",
              "background",
              "bgcolor",
              "border",
              "cellpadding",
              "cellspacing",
              "frame",
              "hspace",
              "rules",
              "valign",
              "vspace"
            ] or String.starts_with?(k, "data-readability-")
          end)
          |> drop_deprecated_size_attrs(tag)
          |> keep_only_preserved_classes(preserve_classes)

        {tag, attrs, children}

      other ->
        other
    end)
  end

  defp drop_deprecated_size_attrs(attrs, tag) do
    tag = String.downcase(tag)

    if tag in ["table", "th", "td", "hr", "pre"] do
      attrs
      |> List.keydelete("width", 0)
      |> List.keydelete("height", 0)
    else
      attrs
    end
  end

  def replace_javascript_links(node) do
    Floki.traverse_and_update(node, fn
      {"a", attrs, children} ->
        href = attr(attrs, "href") |> String.trim()

        if String.match?(href, ~r/^javascript:/i) do
          case children do
            [text] when is_binary(text) ->
              text

            _ ->
              {"span", [], children}
          end
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

  def remove_br_before_p(node) do
    Floki.traverse_and_update(node, fn
      {tag, attrs, children} ->
        {tag, attrs, drop_br_before_p(children)}

      other ->
        other
    end)
  end

  defp drop_br_before_p(children) when is_list(children) do
    do_drop_br(children, [])
  end

  defp drop_br_before_p(children), do: children

  defp do_drop_br([], acc), do: Enum.reverse(acc)

  defp do_drop_br([{"br", _, _} = br | rest], acc) do
    if next_non_whitespace_is_p?(rest) do
      do_drop_br(rest, acc)
    else
      do_drop_br(rest, [br | acc])
    end
  end

  defp do_drop_br([child | rest], acc), do: do_drop_br(rest, [child | acc])

  defp next_non_whitespace_is_p?(children) do
    children
    |> Enum.find(fn
      s when is_binary(s) -> String.trim(s) != ""
      _ -> true
    end)
    |> case do
      {"p", _, _} -> true
      _ -> false
    end
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
          case tag do
            "p" -> Floki.find(node, "img,video,audio,svg,iframe,object,embed") != []
            _ -> Floki.find(node, "img,video,audio,svg,iframe,object,embed,br") != []
          end

        if has_media do
          false
        else
          tag == "p"
        end
      end
    end
  end

  defp keep_only_preserved_classes(attrs, preserve) do
    if is_map(preserve) or is_struct(preserve, MapSet) do
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
    else
      attrs
    end
  end

  defp presentational_attrs do
    [
      "align",
      "background",
      "bgcolor",
      "border",
      "cellpadding",
      "cellspacing",
      "frame",
      "hspace",
      "rules",
      "style",
      "valign",
      "vspace"
    ]
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
            |> abs_attr("href", base, absolute_fragments?, tag)
            |> abs_attr("src", base, true, tag)
            |> abs_attr("poster", base, true, tag)
            |> abs_srcset(base)

          {tag, attrs, children}

        other ->
          other
      end)
    end
  end

  defp abs_attr(attrs, k, base, absolute_fragments?, tag) do
    case List.keyfind(attrs, k, 0) do
      {^k, v} when is_binary(v) and v != "" ->
        cond do
          k == "src" and tag == "iframe" and String.starts_with?(v, "//") ->
            attrs

          should_absolutize?(k, v, absolute_fragments?) ->
            List.keystore(attrs, k, 0, {k, to_abs(v, base)})

          true ->
            attrs
        end

      _ ->
        attrs
    end
  end

  defp abs_srcset(attrs, base) do
    case List.keyfind(attrs, "srcset", 0) do
      {"srcset", v} when is_binary(v) and v != "" ->
        updated =
          Regex.replace(~r/(\S+)(\s+[\d.]+[xw])?(\s*(?:,|$))/, v, fn _m, url, desc, trail ->
            to_abs(url, base) <> (desc || "") <> trail
          end)

        List.keystore(attrs, "srcset", 0, {"srcset", updated})

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
