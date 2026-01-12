defmodule ReadabilityEx.Fixture_ars_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "ars-1"

  test "Readability fixture ars-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
