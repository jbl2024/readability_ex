defmodule ReadabilityEx.Fixture_medium_2Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "medium-2"

  test "Readability fixture medium-2" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
