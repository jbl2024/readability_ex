defmodule ReadabilityEx.Fixture_yahoo_2Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "yahoo-2"

  test "Readability fixture yahoo-2" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
