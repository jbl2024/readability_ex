defmodule ReadabilityEx.Fixture_bloggerTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "blogger"

  test "Readability fixture blogger" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
