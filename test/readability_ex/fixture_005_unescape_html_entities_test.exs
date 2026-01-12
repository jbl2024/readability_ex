defmodule ReadabilityEx.Fixture_005_unescape_html_entitiesTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "005-unescape-html-entities"

  test "Readability fixture 005-unescape-html-entities" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
