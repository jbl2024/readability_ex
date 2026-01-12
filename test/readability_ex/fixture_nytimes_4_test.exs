defmodule ReadabilityEx.Fixture_nytimes_4Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "nytimes-4"

  test "Readability fixture nytimes-4" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
