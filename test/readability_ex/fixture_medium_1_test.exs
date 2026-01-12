defmodule ReadabilityEx.Fixture_medium_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "medium-1"

  test "Readability fixture medium-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
