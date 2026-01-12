defmodule ReadabilityEx.Fixture_citylab_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "citylab-1"

  test "Readability fixture citylab-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
