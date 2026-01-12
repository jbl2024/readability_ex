defmodule ReadabilityEx.Fixture_olTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "ol"

  test "Readability fixture ol" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
