defmodule ReadabilityEx.Fixture_liberation_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "liberation-1"

  test "Readability fixture liberation-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
