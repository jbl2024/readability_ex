defmodule ReadabilityEx.Fixture_normalize_spacesTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "normalize-spaces"

  test "Readability fixture normalize-spaces" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
