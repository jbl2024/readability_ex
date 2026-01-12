defmodule ReadabilityEx.Fixture_wordpressTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "wordpress"

  test "Readability fixture wordpress" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
