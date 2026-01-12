defmodule ReadabilityEx.Fixture_wapo_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "wapo-1"

  test "Readability fixture wapo-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
