defmodule ReadabilityEx.SimplifyNestedElementsTest do
  use ExUnit.Case

  alias ReadabilityEx.Cleaner

  defp parse_fragment(html) do
    html
    |> Floki.parse_fragment!()
    |> List.first()
  end

  test "removes empty divs with only br/hr" do
    html = "<div id=\"wrap\"><br><hr></div>"
    cleaned = html |> parse_fragment() |> Cleaner.simplify_nested_elements()

    assert cleaned == nil
  end

  test "unwraps single div child and preserves parent attributes" do
    html = """
    <div id="parent" class="outer">
      <div id="child" class="inner">Text</div>
    </div>
    """

    cleaned = html |> parse_fragment() |> Cleaner.simplify_nested_elements()

    assert Floki.find(cleaned, "div#parent") != []
    assert Floki.find(cleaned, "div#child") == []
    assert Floki.find(cleaned, "div.outer") != []
    assert Floki.find(cleaned, "div.inner") == []
  end

  test "does not unwrap readability containers" do
    html = """
    <div id="readability-content">
      <div id="child">Text</div>
    </div>
    """

    cleaned = html |> parse_fragment() |> Cleaner.simplify_nested_elements()

    assert Floki.find(cleaned, "#readability-content #child") != []
  end
end
