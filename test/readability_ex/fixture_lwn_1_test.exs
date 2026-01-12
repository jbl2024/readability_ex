defmodule ReadabilityEx.Fixture_lwn_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "lwn-1"

  test "Readability fixture lwn-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
