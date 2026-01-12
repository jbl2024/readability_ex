defmodule ReadabilityEx.Fixture_royal_roadTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "royal-road"

  test "Readability fixture royal-road" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
