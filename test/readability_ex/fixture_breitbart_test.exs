defmodule ReadabilityEx.Fixture_breitbartTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "breitbart"

  test "Readability fixture breitbart" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
