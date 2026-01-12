defmodule ReadabilityEx.Fixture_simplyfound_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "simplyfound-1"

  test "Readability fixture simplyfound-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
