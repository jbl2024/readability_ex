defmodule ReadabilityEx.Fixture_wikiaTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "wikia"

  test "Readability fixture wikia" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
