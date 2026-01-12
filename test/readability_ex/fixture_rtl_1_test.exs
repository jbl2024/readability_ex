defmodule ReadabilityEx.Fixture_rtl_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "rtl-1"

  test "Readability fixture rtl-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
