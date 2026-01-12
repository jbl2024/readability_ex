defmodule ReadabilityEx.Fixture_msnTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "msn"

  test "Readability fixture msn" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
