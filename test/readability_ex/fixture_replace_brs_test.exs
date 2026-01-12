defmodule ReadabilityEx.Fixture_replace_brsTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "replace-brs"

  test "Readability fixture replace-brs" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
