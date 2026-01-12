defmodule ReadabilityEx.Fixture_style_tags_removalTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "style-tags-removal"

  test "Readability fixture style-tags-removal" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
