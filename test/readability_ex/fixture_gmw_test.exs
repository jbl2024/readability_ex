defmodule ReadabilityEx.Fixture_gmwTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "gmw"

  test "Readability fixture gmw" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
