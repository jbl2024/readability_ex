defmodule ReadabilityEx.Index do
  @moduledoc false

  alias ReadabilityEx.Metrics

  defmodule Node do
    @moduledoc false
    defstruct [
      :id,
      :tag,
      :attrs,
      :parent_id,
      :child_ids,
      :raw,
      :text,
      :link_density,
      :class,
      :id_attr,
      :role,
      :dir,
      :hidden,
      score: 0.0,
      content_score: 0.0,
      is_candidate: false,
      removed: false
    ]
  end

  @spec build(Floki.html_tree()) :: %{integer() => Node.t()}
  def build(doc) do
    {_ids, state} = walk_list(doc, nil, %{}, %{})
    state
  end

  defp walk_list(list, parent_id, state, parent_children_acc) when is_list(list) do
    Enum.reduce(list, {[], state}, fn item, {ids, st} ->
      case walk(item, parent_id, st, parent_children_acc) do
        {nil, st2} -> {ids, st2}
        {id, st2} -> {[id | ids], st2}
      end
    end)
    |> then(fn {ids, st} -> {Enum.reverse(ids), st} end)
  end

  # Ignore comments
  defp walk({:comment, _}, _parent_id, state, _acc), do: {nil, state}

  # Ignore doctype
  defp walk({:doctype, _}, _parent_id, state, _acc), do: {nil, state}

  defp walk(text, _parent_id, state, _acc) when is_binary(text), do: {nil, state}

  defp walk({tag, attrs, children} = raw, parent_id, state, _acc) do
    id = System.unique_integer([:positive])
    tag = String.downcase(tag)

    class = get_attr(attrs, "class")
    id_attr = get_attr(attrs, "id")
    role = get_attr(attrs, "role")
    dir = get_attr(attrs, "dir")

    hidden =
      get_attr(attrs, "hidden") != "" or
        String.contains?(String.downcase(get_attr(attrs, "style")), "display:none") or
        String.contains?(String.downcase(get_attr(attrs, "style")), "visibility:hidden")

    {child_ids, state} = walk_list(children, id, state, %{})

    node = %Node{
      id: id,
      tag: tag,
      attrs: attrs,
      parent_id: parent_id,
      child_ids: child_ids,
      raw: raw,
      text: Floki.text(raw),
      link_density: Metrics.link_density(raw),
      class: class,
      id_attr: id_attr,
      role: role,
      dir: dir,
      hidden: hidden
    }

    {id, Map.put(state, id, node)}
  end

  defp get_attr(attrs, k) do
    case List.keyfind(attrs, k, 0) do
      {_, v} -> v
      _ -> ""
    end
  end
end
