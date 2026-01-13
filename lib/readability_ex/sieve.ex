defmodule ReadabilityEx.Sieve do
  @moduledoc false

  alias ReadabilityEx.{Cleaner, Constants, Metadata, Metrics}

  @spec grab_article(
          map(),
          Floki.html_tree(),
          integer(),
          binary(),
          boolean(),
          binary(),
          keyword()
        ) ::
          {:ok, map()} | {:error, atom()}
  def grab_article(state, _doc, flags, base_uri, absolute_fragments?, article_title, opts) do
    state =
      state
      |> drop_hidden()
      |> drop_aria_roles()
      |> drop_modal_dialogs()
      |> maybe_strip_unlikely(flags)
      |> drop_empty_containers()

    {state, byline} = drop_bylines(state)
    state = drop_title_duplicates(state, article_title)

    state = score_candidates(state, flags)
    {top_id, top_candidates, state} = pick_top_candidate(state, opts)

    cond do
      is_nil(top_id) ->
        {:error, :no_candidate}

      true ->
        {top_id, state} = promote_common_ancestor(top_id, top_candidates, state, flags)
        {top_id, state} = promote_content_ancestor(top_id, state)
        top_id = promote_article_container(top_id, state)
        top_id = promote_byline_container(top_id, state)

        article_node = build_article_node(top_id, state, flags)

        cleaned =
          article_node
          |> Cleaner.clean_styles()
          |> Cleaner.mark_data_tables()
          |> Cleaner.fix_lazy_images()
          |> Cleaner.remove_semantic_junk()
          |> Cleaner.clean_share_elements(Constants.default_char_threshold())
          |> Cleaner.remove_title_headers(article_title)
          |> Cleaner.clean_headers()
          |> maybe_clean_conditionally(flags)
          |> Cleaner.wrap_continue_links()
          |> Cleaner.flatten_tables()
          |> Cleaner.downgrade_h1()
          |> Cleaner.simplify_nested_elements()
          |> Cleaner.unwrap_content_main()
          |> Cleaner.absolutize_uris(base_uri, absolute_fragments?)
          |> Cleaner.replace_javascript_links()
          |> Cleaner.remove_empty_nodes()
          |> Cleaner.remove_br_before_p()
          |> Cleaner.simplify_nested_elements()
          |> Cleaner.strip_attributes_and_classes(
            if(opts[:keep_classes], do: nil, else: opts[:preserve_classes])
          )

        {:ok,
         %{
           content_html: Floki.raw_html(cleaned),
           text: Floki.text(cleaned),
           byline: byline || find_byline_near(top_id, state),
           dir: Metadata.get_direction(top_id, state)
         }}
    end
  end

  defp drop_hidden(state) do
    state
    |> Enum.reject(fn {_id, n} -> n.hidden end)
    |> Map.new()
  end

  defp drop_aria_roles(state) do
    roles = Constants.unlikely_roles()

    state
    |> Enum.reject(fn {_id, n} ->
      r = (n.role || "") |> String.downcase()
      r != "" and MapSet.member?(roles, r)
    end)
    |> Map.new()
  end

  defp drop_modal_dialogs(state) do
    Enum.reject(state, fn {_id, n} ->
      aria_modal = attr(n.attrs, "aria-modal") |> String.downcase()
      aria_modal == "true" and (n.role || "") |> String.downcase() == "dialog"
    end)
    |> Map.new()
  end

  defp drop_title_duplicates(state, title) do
    title = (title || "") |> String.trim()

    if title == "" do
      state
    else
      matching =
        state
        |> Enum.filter(fn {_id, n} -> n.tag in ["h1", "h2"] end)
        |> Enum.filter(fn {_id, n} -> text_similarity(title, n.text || "") > 0.75 end)

      case matching do
        [] ->
          state

        _ ->
          {id, _} = Enum.min_by(matching, fn {id, _} -> id end)
          Map.delete(state, id)
      end
    end
  end

  defp text_similarity(text_a, text_b) do
    tokens_a = tokenize(text_a)
    tokens_b = tokenize(text_b)
    token_set_a = MapSet.new(tokens_a)

    if tokens_a == [] or tokens_b == [] do
      0.0
    else
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

  defp maybe_strip_unlikely(state, flags) do
    if Constants.has_flag?(flags, Constants.flag_strip_unlikelys()) do
      Enum.reject(state, fn {_id, n} ->
        s = (n.class || "") <> " " <> (n.id_attr || "")

        Regex.match?(Constants.re_unlikely(), s) and not Regex.match?(Constants.re_ok_maybe(), s) and
          not has_ancestor_tag?(n.id, state, "table") and
          not has_ancestor_tag?(n.id, state, "code") and
          n.tag not in ["body", "a"]
      end)
      |> Map.new()
    else
      state
    end
  end

  defp score_candidates(state, flags) do
    candidate_tags = Constants.candidate_tags()

    Enum.reduce(state, state, fn {id, n}, acc ->
      if MapSet.member?(candidate_tags, n.tag) and String.length(n.text || "") >= 25 do
        comma_segments = n.text |> String.split(Constants.re_commas()) |> length()
        len_bonus = min(n.text |> String.length() |> Kernel./(100) |> Float.floor(), 3.0)
        content_score = 1.0 + comma_segments + len_bonus

        ancestors = ancestor_ids(id, state, 5)

        Enum.reduce(Enum.with_index(ancestors), acc, fn {ancestor_id, level}, acc2 ->
          case acc2[ancestor_id] do
            nil ->
              acc2

            ancestor ->
              ancestor =
                if ancestor.is_candidate do
                  ancestor
                else
                  base = tag_score_base(ancestor.tag) + class_weight(ancestor, flags)
                  %{ancestor | is_candidate: true, score: base, content_score: base}
                end

              divider =
                case level do
                  0 -> 1
                  1 -> 2
                  _ -> level * 3
                end

              add = content_score / divider

              updated = %{
                ancestor
                | score: ancestor.score + add,
                  content_score: ancestor.content_score + add,
                  is_candidate: true
              }

              Map.put(acc2, ancestor_id, updated)
          end
        end)
      else
        acc
      end
    end)
  end

  defp pick_top_candidate(state, opts) do
    candidates =
      state
      |> Enum.filter(fn {_id, n} ->
        n.is_candidate and n.tag not in ["html", "body", "head"]
      end)

    state =
      Enum.reduce(candidates, state, fn {id, n}, acc ->
        final = n.content_score * (1.0 - (n.link_density || 0.0))
        updated = %{n | score: final, content_score: final}
        Map.put(acc, id, updated)
      end)

    nb_top = opts[:nb_top_candidates] || 5

    top_candidates =
      state
      |> Enum.filter(fn {_id, n} ->
        n.is_candidate and n.tag not in ["html", "body", "head"]
      end)
      |> Enum.sort_by(fn {_id, n} -> n.score end, :desc)
      |> Enum.take(nb_top)
      |> Enum.map(fn {id, _n} -> id end)

    top_id = List.first(top_candidates)

    if is_nil(top_id) or (state[top_id] && state[top_id].score <= 0.0) do
      body_id =
        state
        |> Enum.find_value(fn {id, n} -> if n.tag == "body", do: id, else: nil end)

      {body_id || top_id, top_candidates, state}
    else
      {top_id, top_candidates, state}
    end
  end

  defp promote_common_ancestor(top_id, top_candidates, state, flags) do
    top = state[top_id]

    if is_nil(top) do
      {top_id, state}
    else
      top_score = max(0.0001, top.score)

      alternative_candidates =
        top_candidates
        |> Enum.drop(1)
        |> Enum.filter(fn id ->
          case state[id] do
            nil -> false
            n -> n.score / top_score >= 0.75
          end
        end)

      alternative_ancestors =
        Enum.map(alternative_candidates, fn id -> ancestor_chain(id, state) end)

      min_candidates = 3

      {top_id, state} =
        if length(alternative_ancestors) >= min_candidates do
          parent_id = top.parent_id

          find_common_ancestor(parent_id, alternative_ancestors, state, min_candidates) || top_id
        else
          top_id
        end
        |> ensure_initialized(state, flags)

      {top_id, state}
    end
  end

  defp promote_content_ancestor(top_id, state) do
    top = state[top_id]

    if is_nil(top) do
      {top_id, state}
    else
      parent_id = top.parent_id
      last_score = top.score
      score_threshold = last_score / 3.0

      {top_id, state} =
        Stream.iterate(parent_id, fn id -> state[id] && state[id].parent_id end)
        |> Enum.reduce_while({top_id, state, last_score}, fn id, {current_id, st, last} ->
          case st[id] do
            nil ->
              {:halt, {current_id, st, last}}

            parent ->
              cond do
                parent.tag == "body" ->
                  {:halt, {current_id, st, last}}

                not parent.is_candidate ->
                  {:cont, {current_id, st, last}}

                parent.score < score_threshold ->
                  {:halt, {current_id, st, last}}

                parent.score > last ->
                  {:halt, {id, st, parent.score}}

                true ->
                  {:cont, {current_id, st, parent.score}}
              end
          end
        end)
        |> then(fn {id, st, _last} -> {id, st} end)

      top_id = promote_single_child(top_id, state)

      {top_id, state}
    end
  end

  defp promote_article_container(top_id, state) do
    chain =
      Stream.iterate(top_id, fn id -> state[id] && state[id].parent_id end)
      |> Enum.take_while(& &1)
      |> Enum.map(&state[&1])
      |> Enum.reject(&is_nil/1)

    chain
    |> Enum.filter(&article_container?/1)
    |> List.last()
    |> case do
      nil -> top_id
      node -> node.id
    end
  end

  defp promote_byline_container(top_id, state) do
    case state[top_id] do
      nil ->
        top_id

      node ->
        parent = node.parent_id && state[node.parent_id]

        if parent && parent.tag != "body" and parent_has_byline_child?(parent, state) do
          parent.id
        else
          top_id
        end
    end
  end

  defp parent_has_byline_child?(parent, state) do
    Enum.any?(parent.child_ids, fn id ->
      case state[id] do
        nil ->
          false

        child ->
          match_string = (child.class || "") <> " " <> (child.id_attr || "")
          Regex.match?(Constants.re_byline(), match_string) and String.length(child.text || "") > 0
      end
    end)
  end

  defp article_container?(node) do
    tag = node.tag
    id_attr = node.id_attr || ""

    tag in ["section", "article"] and
      Regex.match?(~r/\bnews-article\b|\bstory\b/i, id_attr)
  end

  defp ancestor_chain(id, state) do
    Enum.reduce_while(
      Stream.iterate(id, fn x -> state[x] && state[x].parent_id end),
      [],
      fn x, acc ->
        if is_nil(x) do
          {:halt, acc}
        else
          {:cont, [x | acc]}
        end
      end
    )
    |> Enum.reverse()
  end

  defp build_article_node(top_id, state, _flags) do
    top = state[top_id]
    siblings = siblings_of(top_id, state)

    top_final = top.score
    threshold = max(10.0, top_final * 0.2)

    if top.tag == "body" do
      {_tag, _attrs, children} = top.raw
      {"div", [{"id", "readability-page-1"}, {"class", "page"}], children}
    else
      kept =
        siblings
        |> Enum.map(fn sib -> {sib, keep_sibling?(sib, top_id, top, threshold)} end)
        |> keep_separator_siblings()
        |> Enum.filter(fn {_sib, keep?} -> keep? end)
        |> Enum.map(fn {sib, _} ->
          if alter_to_div?(sib.tag) do
            set_node_tag(sib.raw, "div")
          else
            sib.raw
          end
        end)

      {"div", [{"id", "readability-page-1"}, {"class", "page"}], kept}
    end
  end

  defp same_class?(sib, top) do
    (sib.class || "") != "" and (sib.class || "") == (top.class || "")
  end

  defp siblings_of(id, state) do
    pid = state[id].parent_id

    case state[pid] do
      nil ->
        state
        |> Map.values()
        |> Enum.filter(fn n -> n.parent_id == pid end)

      parent ->
        parent.child_ids
        |> Enum.map(&state[&1])
        |> Enum.reject(&is_nil/1)
    end
  end

  defp alter_to_div?(tag) do
    tag not in ["div", "article", "section", "p", "ol", "ul", "blockquote", "hr", "b", "strong"]
  end

  defp keep_sibling?(sib, top_id, top, threshold) do
    content_bonus =
      if same_class?(sib, top) and (top.class || "") != "" do
        top.score * 0.2
      else
        0.0
      end

    cond do
      sib.id == top_id ->
        true

      sib.is_candidate and sib.score + content_bonus >= threshold ->
        true

      Regex.match?(Constants.re_byline(), (sib.class || "") <> " " <> (sib.id_attr || "")) and
          String.length(sib.text || "") > 0 ->
        true

      same_class?(sib, top) and String.length(sib.text || "") > 0 and
          (sib.link_density || 0.0) < 0.3 ->
        true

      sib.tag in ["p", "ul", "ol"] and String.length(sib.text || "") > 80 and
          (sib.link_density || 0.0) < 0.25 ->
        true

      sib.tag in ["p", "ul", "ol"] and String.length(sib.text || "") < 80 and
        String.length(sib.text || "") > 0 and (sib.link_density || 0.0) == 0.0 and
          String.match?(sib.text || "", ~r/[\.\?!]( |$)/) ->
        true

      sib.tag == "p" and String.length(sib.text || "") == 0 and has_media?(sib.raw) ->
        true

      sib.tag in ["b", "strong"] and String.length(sib.text || "") > 0 ->
        true

      sib.tag == "blockquote" and String.length(sib.text || "") > 0 ->
        true

      sib.tag == "hr" ->
        true

      true ->
        false
    end
  end

  defp keep_separator_siblings(siblings_with_flags) do
    case Enum.find_index(siblings_with_flags, fn {_sib, keep?} -> keep? end) do
      nil ->
        siblings_with_flags

      first_idx ->
        last_idx =
          siblings_with_flags
          |> Enum.with_index()
          |> Enum.reduce(first_idx, fn {{_sib, keep?}, idx}, acc ->
            if keep?, do: idx, else: acc
          end)

        siblings_with_flags
        |> Enum.with_index()
        |> Enum.map(fn {{sib, keep?}, idx} ->
          if keep? or
               (idx >= first_idx and idx <= last_idx and sib.tag in ["hr", "b", "strong"]) do
            {sib, true}
          else
            {sib, false}
          end
        end)
    end
  end

  defp has_media?(node) do
    Floki.find(node, "img,embed,object,iframe") != []
  end

  defp set_node_tag({_tag, attrs, children}, new_tag) do
    {new_tag, attrs, children}
  end

  defp maybe_clean_conditionally(node, flags) do
    if Constants.has_flag?(flags, Constants.flag_clean_conditionally()) do
      Cleaner.clean_conditionally(node)
    else
      node
    end
  end

  defp find_byline_near(top_id, state) do
    # Simple heuristic: search ancestors for byline-like descendants
    chain =
      Stream.iterate(top_id, fn x -> state[x] && state[x].parent_id end)
      |> Enum.take_while(&(!is_nil(&1)))

    candidates =
      chain
      |> Enum.flat_map(fn id ->
        case state[id] do
          nil -> []
          n -> find_all_bylines_in(n.raw)
        end
      end)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(fn text -> String.length(text) in 3..120 end)
      |> Enum.uniq()

    best =
      candidates
      |> Enum.sort_by(fn text -> {byline_priority(text), String.length(text)} end, :desc)
      |> List.first()

    if is_nil(best) or String.length(best) <= 4 do
      fallback_byline(top_id, state) || best
    else
      best
    end
  end

  defp find_all_bylines_in(list) when is_list(list) do
    Enum.flat_map(list, &find_all_bylines_in/1)
  end

  defp find_all_bylines_in({_, attrs, children} = node) do
    s = attr(attrs, "class") <> " " <> attr(attrs, "id")

    cond do
      negative_or_unlikely?(s) ->
        []

      itemprop_author?(attrs) or Regex.match?(~r/\bauteur\b/i, s) or rel_author?(attrs) ->
        text =
          node
          |> Floki.text()
          |> String.trim()
          |> String.replace(~r/\s*[\-–—]+$/, "")

        [text] ++ find_all_bylines_in(children)

      Regex.match?(Constants.re_byline(), s) ->
        text =
          node
          |> Floki.text()
          |> String.trim()
          |> String.replace(~r/\s*[\-–—]+$/, "")

        [text] ++ find_all_bylines_in(children)

      true ->
        find_all_bylines_in(children)
    end
  end

  defp find_all_bylines_in(_), do: []

  defp byline_priority(text) do
    if Regex.match?(~r/^(par|by)\b/i, text), do: 2, else: 1
  end

  defp fallback_byline(root_id, state) do
    root_id
    |> collect_nodes_in_order(state)
    |> Enum.find_value(fn n ->
      s = (n.class || "") <> " " <> (n.id_attr || "")

      cond do
        Regex.match?(~r/\bauthorname\b/i, s) ->
          name = n.raw |> Floki.text() |> String.trim()
          if name != "", do: "Par " <> name, else: nil

        true ->
          text = n.raw |> Floki.text() |> String.trim()
          if Regex.match?(~r/^Par\s+\S+/i, text), do: text, else: nil
      end
    end)
    |> case do
      nil -> nil
      text -> if String.length(text) in 3..120, do: text, else: nil
    end
  end

  defp collect_nodes_in_order(nil, _state), do: []

  defp collect_nodes_in_order(id, state) do
    case state[id] do
      nil ->
        []

      node ->
        [node | Enum.flat_map(node.child_ids || [], &collect_nodes_in_order(&1, state))]
    end
  end

  defp negative_or_unlikely?(s) do
    Regex.match?(Constants.re_negative(), s) or Regex.match?(Constants.re_unlikely(), s)
  end

  defp rel_author?(attrs) do
    attrs
    |> attr("rel")
    |> String.downcase()
    |> String.split(~r/\s+/)
    |> Enum.any?(&(&1 == "author"))
  end

  defp itemprop_author?(attrs) do
    attrs
    |> attr("itemprop")
    |> String.downcase()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.any?(&String.contains?(&1, "author"))
  end

  defp attr(attrs, k), do: (List.keyfind(attrs, k, 0) || {k, ""}) |> elem(1)

  defp class_weight(node, flags) do
    if Constants.has_flag?(flags, Constants.flag_weight_classes()) do
      Metrics.class_weight(node.class, node.id_attr)
    else
      0
    end
  end

  defp tag_score_base(tag) do
    case tag do
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
  end

  defp ancestor_ids(id, state, max_depth) do
    Stream.iterate(state[id] && state[id].parent_id, fn pid ->
      state[pid] && state[pid].parent_id
    end)
    |> Enum.take_while(& &1)
    |> Enum.take(max_depth)
  end

  defp has_ancestor_tag?(id, state, tag_name) do
    tag_name = String.downcase(tag_name)

    Stream.iterate(state[id] && state[id].parent_id, fn pid ->
      state[pid] && state[pid].parent_id
    end)
    |> Enum.take(4)
    |> Enum.any?(fn pid ->
      case state[pid] do
        nil -> false
        node -> node.tag == tag_name
      end
    end)
  end

  defp ensure_initialized(top_id, state, flags) do
    case state[top_id] do
      nil ->
        {top_id, state}

      node ->
        if node.is_candidate do
          {top_id, state}
        else
          base = tag_score_base(node.tag) + class_weight(node, flags)
          updated = %{node | is_candidate: true, score: base, content_score: base}
          {top_id, Map.put(state, top_id, updated)}
        end
    end
  end

  defp find_common_ancestor(parent_id, alternative_ancestors, state, min_candidates) do
    case state[parent_id] do
      nil ->
        nil

      parent ->
        if parent.tag == "body" do
          nil
        else
          lists_containing =
            alternative_ancestors
            |> Enum.count(fn chain -> parent_id in chain end)

          if lists_containing >= min_candidates do
            parent_id
          else
            find_common_ancestor(parent.parent_id, alternative_ancestors, state, min_candidates)
          end
        end
    end
  end

  defp promote_single_child(top_id, state) do
    Stream.iterate(top_id, fn id -> state[id] && state[id].parent_id end)
    |> Enum.reduce_while(top_id, fn id, _acc ->
      case state[id] do
        nil ->
          {:halt, top_id}

        node ->
          parent = state[node.parent_id]

          cond do
            is_nil(parent) or parent.tag == "body" ->
              {:halt, id}

            length(parent.child_ids || []) == 1 ->
              {:cont, parent.id}

            true ->
              {:halt, id}
          end
      end
    end)
  end

  defp drop_empty_containers(state) do
    Enum.reject(state, fn {_id, n} ->
      empty_container?(n)
    end)
    |> Map.new()
  end

  defp empty_container?(n) do
    if n.tag in ["div", "section", "header", "h1", "h2", "h3", "h4", "h5", "h6"] do
      text = String.trim(n.text || "")

      if text != "" do
        false
      else
        children = element_children(n.raw)
        br_count = count_tag(children, "br")
        hr_count = count_tag(children, "hr")
        element_count = length(children)
        element_count == 0 or element_count == br_count + hr_count
      end
    else
      false
    end
  end

  defp element_children({_, _, children}) do
    Enum.filter(children, &match?({_, _, _}, &1))
  end

  defp count_tag(children, tag) do
    Enum.count(children, fn
      {^tag, _, _} -> true
      _ -> false
    end)
  end

  defp drop_bylines(state) do
    root_id = find_root_id(state)

    candidates =
      root_id
      |> collect_nodes_in_order(state)
      |> Enum.filter(&valid_byline_node?/1)

    chosen =
      candidates
      |> Enum.filter(fn n -> byline_prefix?(normalize_byline_text(n.text || "")) end)
      |> List.first()
      |> case do
        nil -> List.first(candidates)
        node -> node
      end

    if is_nil(chosen) do
      {state, nil}
    else
      byline = normalize_byline_text(chosen.text || "")

      state =
        Enum.reject(state, fn {id, _n} -> id == chosen.id end)
        |> Map.new()

      {state, byline}
    end
  end

  defp valid_byline_node?(n) do
    match_string = (n.class || "") <> " " <> (n.id_attr || "")
    rel = attr(n.attrs, "rel") |> String.downcase()
    itemprop = attr(n.attrs, "itemprop") |> String.downcase()
    byline_length = String.length(String.trim(n.text || ""))

    (rel == "author" or
       String.contains?(itemprop, "author") or
       Regex.match?(Constants.re_byline(), match_string)) and byline_length > 0 and
      byline_length < 100
  end

  defp normalize_byline_text(text) do
    text
    |> String.trim()
    |> String.replace(~r/\s*[\-–—]+$/, "")
    |> String.trim()
  end

  defp byline_prefix?(text) do
    Regex.match?(~r/^(par|by)\b/i, text)
  end

  defp find_root_id(state) do
    Enum.find_value(state, fn {id, n} -> if n.tag == "html", do: id, else: nil end) ||
      Enum.find_value(state, fn {id, n} -> if n.tag == "body", do: id, else: nil end)
  end
end
