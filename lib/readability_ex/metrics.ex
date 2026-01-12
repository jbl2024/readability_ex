defmodule ReadabilityEx.Metrics do
  @moduledoc false
  alias ReadabilityEx.Constants

  def link_density(node) do
    text = Floki.text(node)
    len = String.length(text)

    if len == 0 do
      0.0
    else
      links_text =
        node
        |> Floki.find("a")
        |> Floki.text()
        |> String.length()

      links_text / len
    end
  end

  def class_weight(class, id_attr) do
    s = (class || "") <> " " <> (id_attr || "")
    w = 0
    w = if Regex.match?(Constants.re_positive(), s), do: w + 25, else: w
    w = if Regex.match?(Constants.re_negative(), s), do: w - 25, else: w
    w
  end
end
