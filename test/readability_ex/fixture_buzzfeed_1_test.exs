defmodule ReadabilityEx.Fixture_buzzfeed_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "buzzfeed-1"

  test "Readability fixture buzzfeed-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
