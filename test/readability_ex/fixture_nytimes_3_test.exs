defmodule ReadabilityEx.Fixture_nytimes_3Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "nytimes-3"

  test "Readability fixture nytimes-3" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
