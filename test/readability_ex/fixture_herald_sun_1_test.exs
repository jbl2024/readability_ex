defmodule ReadabilityEx.Fixture_herald_sun_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "herald-sun-1"

  test "Readability fixture herald-sun-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
