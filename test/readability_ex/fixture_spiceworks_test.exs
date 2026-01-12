defmodule ReadabilityEx.Fixture_spiceworksTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "spiceworks"

  test "Readability fixture spiceworks" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
