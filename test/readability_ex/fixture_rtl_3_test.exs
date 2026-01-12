defmodule ReadabilityEx.Fixture_rtl_3Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "rtl-3"

  test "Readability fixture rtl-3" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
