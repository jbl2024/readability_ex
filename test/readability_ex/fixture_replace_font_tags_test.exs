defmodule ReadabilityEx.Fixture_replace_font_tagsTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "replace-font-tags"

  test "Readability fixture replace-font-tags" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
