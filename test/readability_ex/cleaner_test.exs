defmodule ReadabilityEx.CleanerTest do
  use ExUnit.Case

  alias ReadabilityEx.Cleaner

  defp parse_fragment(html) do
    html
    |> Floki.parse_fragment!()
    |> List.first()
  end

  test "clean_conditionally keeps allowed video embeds" do
    html = """
    <div id="root">
      <div id="container">
        <iframe src="https://www.youtube.com/embed/abc"></iframe>
      </div>
    </div>
    """

    cleaned = html |> parse_fragment() |> Cleaner.clean_conditionally()

    assert Floki.find(cleaned, "#container") != []
  end

  test "clean_conditionally removes negative-weight divs" do
    html = """
    <div id="root">
      <div class="comment">Sponsored</div>
    </div>
    """

    cleaned = html |> parse_fragment() |> Cleaner.clean_conditionally()

    assert Floki.find(cleaned, ".comment") == []
  end

  test "clean_conditionally keeps image-only lists" do
    html = """
    <div id="root">
      <ul id="gallery">
        <li><img src="a.jpg"></li>
        <li><img src="b.jpg"></li>
      </ul>
    </div>
    """

    cleaned = html |> parse_fragment() |> Cleaner.clean_conditionally()

    assert Floki.find(cleaned, "#gallery") != []
  end

  test "clean_share_elements removes low-text share nodes" do
    html = """
    <div id="root">
      <div class="share">Share</div>
      <div class="content">Real content</div>
    </div>
    """

    cleaned =
      html
      |> parse_fragment()
      |> Cleaner.clean_share_elements(500)

    assert Floki.find(cleaned, ".share") == []
    assert Floki.find(cleaned, ".content") != []
  end

  test "clean_styles drops presentational attributes and size on tables" do
    html = """
    <div style="color: red" align="center">
      <table width="100" height="200" border="1"></table>
    </div>
    """

    cleaned = html |> parse_fragment() |> Cleaner.clean_styles()

    assert Floki.find(cleaned, "div[style]") == []
    assert Floki.find(cleaned, "div[align]") == []
    assert Floki.find(cleaned, "table[border]") == []
    assert Floki.find(cleaned, "table[width]") == []
    assert Floki.find(cleaned, "table[height]") == []
  end

  test "clean_styles preserves svg attributes" do
    html = """
    <div>
      <svg style="fill: red"><rect width="10" height="10"></rect></svg>
    </div>
    """

    cleaned = html |> parse_fragment() |> Cleaner.clean_styles()

    assert Floki.find(cleaned, "svg[style]") != []
  end

  test "strip_attributes_and_classes keeps classes when preserve_classes is nil" do
    html = """
    <div class="keep drop" style="color: red"></div>
    """

    cleaned = html |> parse_fragment() |> Cleaner.strip_attributes_and_classes(nil)

    assert Floki.find(cleaned, "div[class]") != []
    assert Floki.find(cleaned, "div[style]") == []
  end
end
