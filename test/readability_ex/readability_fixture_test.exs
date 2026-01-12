defmodule ReadabilityEx.ReadabilityFixtureTest do
  use ExUnit.Case, async: false

  alias ReadabilityEx.TestHelpers

  @moduletag :fixtures

  describe "ReadabilityEx vs Mozilla test suite" do
    for id <- TestHelpers.fixture_dirs() do
      test "fixture #{id}" do
        fix = TestHelpers.read_fixture(unquote(id))

        # 1. Run extractor
        {:ok, result} =
          ReadabilityEx.parse(
            fix.source,
            base_uri: "https://example.com"
          )

        # 2. HTML comparison
        expected_html =
          fix.expected_html
          |> TestHelpers.normalize_html()

        actual_html =
          result.content
          |> TestHelpers.normalize_html()

        assert actual_html == expected_html

        # 3. Metadata checks
        meta = fix.expected_meta

        assert result.title == meta["title"]
        assert result.byline == meta["byline"]
        assert result.lang == meta["lang"]
        assert result.siteName == meta["siteName"]
        assert result.publishedTime == meta["publishedTime"]

        # dir: Readability renvoie parfois null
        if meta["dir"] do
          assert result.dir == meta["dir"]
        end

        # 4. Excerpt: on compare normalisé
        if meta["excerpt"] do
          assert TestHelpers.normalize_text(result.excerpt) ==
                   TestHelpers.normalize_text(meta["excerpt"])
        end

        # 5. Readerable flag
        if meta["readerable"] do
          assert result.length > 0
        end
      end
    end
  end
end
