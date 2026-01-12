defmodule ReadabilityEx.Fixture_wikipedia_3Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "wikipedia-3"

  test "Readability fixture wikipedia-3" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
