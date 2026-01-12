defmodule ReadabilityEx.Fixture_clean_linksTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "clean-links"

  test "Readability fixture clean-links" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
