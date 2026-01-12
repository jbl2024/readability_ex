defmodule ReadabilityEx.Fixture_medium_3Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "medium-3"

  test "Readability fixture medium-3" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
