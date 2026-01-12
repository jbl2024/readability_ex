defmodule ReadabilityEx.Fixture_lemonde_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "lemonde-1"

  test "Readability fixture lemonde-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
