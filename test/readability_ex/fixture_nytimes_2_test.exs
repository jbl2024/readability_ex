defmodule ReadabilityEx.Fixture_nytimes_2Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "nytimes-2"

  test "Readability fixture nytimes-2" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
