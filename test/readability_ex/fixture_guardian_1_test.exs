defmodule ReadabilityEx.Fixture_guardian_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "guardian-1"

  test "Readability fixture guardian-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
