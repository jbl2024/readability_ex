defmodule ReadabilityEx.Fixture_wikipedia_4Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "wikipedia-4"

  test "Readability fixture wikipedia-4" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
