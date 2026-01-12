defmodule ReadabilityEx.Fixture_wikipediaTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "wikipedia"

  test "Readability fixture wikipedia" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
