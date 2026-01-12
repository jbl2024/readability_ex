defmodule ReadabilityEx.Fixture_rtl_2Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "rtl-2"

  test "Readability fixture rtl-2" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
