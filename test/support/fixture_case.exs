defmodule ReadabilityEx.FixtureCase do
  @moduledoc false

  import ExUnit.Assertions

  alias ReadabilityEx.TestHelpers

  def run_fixture(id) do
    fix = TestHelpers.read_fixture(id)

    {:ok, result} =
      ReadabilityEx.parse(
        fix.source,
        base_uri: "http://fakehost"
      )

    expected_html =
      fix.expected_html
      |> TestHelpers.normalize_html()

    actual_html =
      result.content
      |> TestHelpers.normalize_html()

    assert actual_html == expected_html

    meta = fix.expected_meta

    assert result.title == meta["title"]
    assert result.byline == meta["byline"]
    assert result.lang == meta["lang"]
    assert result.siteName == meta["siteName"]
    assert result.publishedTime == meta["publishedTime"]

    if meta["dir"] do
      assert result.dir == meta["dir"]
    end

    if meta["excerpt"] do
      assert TestHelpers.normalize_text(result.excerpt) ==
               TestHelpers.normalize_text(meta["excerpt"])
    end

    if meta["readerable"] do
      assert result.length > 0
    end
  end
end
