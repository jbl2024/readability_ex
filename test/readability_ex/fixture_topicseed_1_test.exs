defmodule ReadabilityEx.Fixture_topicseed_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "topicseed-1"

  test "Readability fixture topicseed-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
