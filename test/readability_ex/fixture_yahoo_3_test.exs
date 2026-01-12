defmodule ReadabilityEx.Fixture_yahoo_3Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "yahoo-3"

  test "Readability fixture yahoo-3" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
