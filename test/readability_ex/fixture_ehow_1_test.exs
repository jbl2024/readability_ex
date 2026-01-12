defmodule ReadabilityEx.Fixture_ehow_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "ehow-1"

  test "Readability fixture ehow-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
