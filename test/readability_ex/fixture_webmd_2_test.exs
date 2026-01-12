defmodule ReadabilityEx.Fixture_webmd_2Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "webmd-2"

  test "Readability fixture webmd-2" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
