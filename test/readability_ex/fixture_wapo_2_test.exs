defmodule ReadabilityEx.Fixture_wapo_2Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "wapo-2"

  test "Readability fixture wapo-2" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
