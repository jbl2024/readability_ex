defmodule ReadabilityEx.Fixture_tumblrTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "tumblr"

  test "Readability fixture tumblr" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
