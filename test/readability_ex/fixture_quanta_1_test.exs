defmodule ReadabilityEx.Fixture_quanta_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "quanta-1"

  test "Readability fixture quanta-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
