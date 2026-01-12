defmodule ReadabilityEx.Fixture_nytimes_5Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "nytimes-5"

  test "Readability fixture nytimes-5" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
