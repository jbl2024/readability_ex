defmodule ReadabilityEx.Fixture_webmd_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "webmd-1"

  test "Readability fixture webmd-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
