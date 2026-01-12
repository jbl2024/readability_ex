defmodule ReadabilityEx.Fixture_seattletimes_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "seattletimes-1"

  test "Readability fixture seattletimes-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
