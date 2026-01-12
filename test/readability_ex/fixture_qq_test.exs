defmodule ReadabilityEx.Fixture_qqTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "qq"

  test "Readability fixture qq" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
