defmodule ReadabilityEx.FixRelativeUrisTest do
  use ExUnit.Case

  alias ReadabilityEx.Cleaner

  defp parse_fragment(html) do
    html
    |> Floki.parse_fragment!()
    |> List.first()
  end

  test "keeps hash links when absolute_fragments is false" do
    html = """
    <div><a href="#section">Link</a></div>
    """

    cleaned = html |> parse_fragment() |> Cleaner.absolutize_uris("https://example.com/path/", false)

    assert Floki.find(cleaned, "a[href='#section']") != []
  end

  test "absolutizes hash links when absolute_fragments is true" do
    html = """
    <div><a href="#section">Link</a></div>
    """

    cleaned = html |> parse_fragment() |> Cleaner.absolutize_uris("https://example.com/path/", true)

    assert Floki.find(cleaned, "a[href='https://example.com/path/#section']") != []
  end

  test "absolutizes protocol-relative iframe sources" do
    html = """
    <div><iframe src="//cdn.example.com/video"></iframe></div>
    """

    cleaned = html |> parse_fragment() |> Cleaner.absolutize_uris("https://example.com/path/", true)

    assert Floki.find(cleaned, "iframe[src='https://cdn.example.com/video']") != []
  end
end
