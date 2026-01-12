defmodule ReadabilityEx.Fixture_yahoo_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "yahoo-1"

  test "Readability fixture yahoo-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
