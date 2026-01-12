defmodule ReadabilityEx.Fixture_iab_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "iab-1"

  test "Readability fixture iab-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
