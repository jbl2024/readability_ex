defmodule ReadabilityEx.Fixture_heiseTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "heise"

  test "Readability fixture heise" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
