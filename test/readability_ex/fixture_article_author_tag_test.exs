defmodule ReadabilityEx.Fixture_article_author_tagTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "article-author-tag"

  test "Readability fixture article-author-tag" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
