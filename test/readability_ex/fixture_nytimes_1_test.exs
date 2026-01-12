defmodule ReadabilityEx.Fixture_nytimes_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "nytimes-1"

  test "Readability fixture nytimes-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
