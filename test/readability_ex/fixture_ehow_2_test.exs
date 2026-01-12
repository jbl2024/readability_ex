defmodule ReadabilityEx.Fixture_ehow_2Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "ehow-2"

  test "Readability fixture ehow-2" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
