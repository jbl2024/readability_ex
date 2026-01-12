defmodule ReadabilityEx.Fixture_wikipedia_2Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "wikipedia-2"

  test "Readability fixture wikipedia-2" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
