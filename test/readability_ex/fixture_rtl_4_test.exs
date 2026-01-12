defmodule ReadabilityEx.Fixture_rtl_4Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "rtl-4"

  test "Readability fixture rtl-4" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
