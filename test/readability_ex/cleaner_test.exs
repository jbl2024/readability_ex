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
end
