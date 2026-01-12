defmodule ReadabilityEx.Sieve do
  @moduledoc false

  alias ReadabilityEx.{Cleaner, Constants, Metadata, Metrics}

  @spec grab_article(map(), Floki.html_tree(), integer(), binary(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def grab_article(state, _doc, flags, base_uri, opts) do
    state =
      state
      |> drop_hidden()
      |> drop_aria_roles()
      |> maybe_strip_unlikely(flags)

    state = score_candidates(state, flags)
    state = propagate_scores(state)
    {top_id, state} = pick_top_candidate(state)

    cond do
      is_nil(top_id) ->
        {:error, :no_candidate}

      true ->
        top_id = promote_common_ancestor(top_id, state)
        article_node = build_article_node(top_id, state, flags)

        cleaned =
          article_node
          |> Cleaner.fix_lazy_images()
          |> maybe_clean_conditionally(flags)
          |> Cleaner.simplify_nested_elements()
          |> Cleaner.absolutize_uris(base_uri)
          |> Cleaner.strip_attributes_and_classes(opts[:preserve_classes])

        {:ok,
         %{
           content_html: Floki.raw_html(cleaned),
           text: Floki.text(cleaned),
           byline: find_byline_near(top_id, state),
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

  defp maybe_strip_unlikely(state, flags) do
    if Constants.has_flag?(flags, Constants.flag_strip_unlikelys()) do
      Enum.reject(state, fn {_id, n} ->
        s = (n.class || "") <> " " <> (n.id_attr || "")
        Regex.match?(Constants.re_unlikely(), s) and not Regex.match?(Constants.re_ok_maybe(), s)
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
        base = 1.0 + comma_segments + len_bonus

        weight =
          if Constants.has_flag?(flags, Constants.flag_weight_classes()) do
            Metrics.class_weight(n.class, n.id_attr)
          else
            0
          end

        score = base + weight
        Map.put(acc, id, %{n | is_candidate: true, content_score: score, score: score})
      else
        acc
      end
    end)
  end

  defp propagate_scores(state) do
    candidates = Enum.filter(state, fn {_id, n} -> n.is_candidate end)

    Enum.reduce(candidates, state, fn {_id, n}, acc ->
      propagate_up(n.parent_id, n.content_score, 0, acc)
    end)
  end

  defp propagate_up(nil, _score, _level, state), do: state

  defp propagate_up(pid, score, level, state) do
    case state[pid] do
      nil ->
        state

      parent ->
        divider =
          case level do
            0 -> 1
            1 -> 2
            _ -> level * 3
          end

        add = score / divider
        updated = %{parent | score: parent.score + add, content_score: parent.content_score + add}
        state = Map.put(state, pid, updated)
        propagate_up(parent.parent_id, score, level + 1, state)
    end
  end

  defp pick_top_candidate(state) do
    top =
      state
      |> Enum.map(fn {id, n} ->
        final = n.score * (1.0 - (n.link_density || 0.0))
        {id, final}
      end)
      |> Enum.max_by(fn {_id, s} -> s end, fn -> {nil, 0.0} end)

    {elem(top, 0), state}
  end

  defp promote_common_ancestor(top_id, state) do
    top = state[top_id]
    top_score = max(0.0001, top.score)

    alts =
      state
      |> Enum.filter(fn {id, n} ->
        id != top_id and n.is_candidate and n.score / top_score >= 0.75
      end)
      |> Enum.map(fn {id, _} -> id end)

    if length(alts) < 3 do
      top_id
    else
      all = [top_id | alts]
      ancestors = Enum.map(all, &ancestor_chain(&1, state))

      common =
        ancestors
        |> Enum.reduce(fn a, b -> MapSet.intersection(a, b) end)
        |> MapSet.to_list()

      # Pick closest common ancestor that is not nil
      chosen =
        common
        |> Enum.map(fn aid -> {aid, depth_from(top_id, aid, state)} end)
        |> Enum.reject(fn {aid, d} -> is_nil(aid) or is_nil(d) end)
        |> Enum.sort_by(fn {_aid, d} -> d end)
        |> Enum.map(fn {aid, _} -> aid end)
        |> List.first()

      chosen || top_id
    end
  end

  defp ancestor_chain(id, state) do
    Enum.reduce_while(
      Stream.iterate(id, fn x -> state[x] && state[x].parent_id end),
      MapSet.new(),
      fn x, acc ->
        if is_nil(x) do
          {:halt, acc}
        else
          {:cont, MapSet.put(acc, x)}
        end
      end
    )
  end

  defp depth_from(child, ancestor, state) do
    do_depth(child, ancestor, state, 0)
  end

  defp do_depth(nil, _a, _s, _d), do: nil
  defp do_depth(a, a, _s, d), do: d
  defp do_depth(c, a, s, d), do: do_depth(s[c] && s[c].parent_id, a, s, d + 1)

  defp build_article_node(top_id, state, _flags) do
    top = state[top_id]
    siblings = siblings_of(top_id, state)

    top_final = top.score * (1.0 - top.link_density)
    threshold = max(10.0, top_final * 0.2)

    kept =
      siblings
      |> Enum.filter(fn sib ->
        cond do
          sib.id == top_id ->
            true

          sib.score >= threshold ->
            true

          same_class?(sib, top) ->
            true

          sib.tag == "p" and String.length(sib.text || "") > 80 and
              (sib.link_density || 0.0) < 0.25 ->
            true

          true ->
            false
        end
      end)
      |> Enum.map(& &1.raw)

    {"div", [{"id", "readability-content"}], kept}
  end

  defp same_class?(sib, top) do
    (sib.class || "") != "" and (sib.class || "") == (top.class || "")
  end

  defp siblings_of(id, state) do
    pid = state[id].parent_id

    state
    |> Map.values()
    |> Enum.filter(fn n -> n.parent_id == pid end)
  end

  defp maybe_clean_conditionally(node, flags) do
    if Constants.has_flag?(flags, Constants.flag_clean_conditionally()) do
      Cleaner.clean_conditionally(node)
    else
      node
    end
  end

  defp find_byline_near(top_id, state) do
    # Simple heuristic: search ancestors for byline-like nodes
    chain =
      Stream.iterate(top_id, fn x -> state[x] && state[x].parent_id end)
      |> Enum.take_while(&(!is_nil(&1)))

    chain
    |> Enum.map(&state[&1])
    |> Enum.find_value(fn n ->
      s = (n.class || "") <> " " <> (n.id_attr || "")

      if Regex.match?(Constants.re_byline(), s) and String.length(n.text || "") in 3..120 do
        String.trim(n.text)
      else
        nil
      end
    end)
  end
end
