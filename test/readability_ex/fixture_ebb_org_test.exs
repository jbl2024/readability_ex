defmodule ReadabilityEx.Fixture_ebb_orgTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "ebb-org"

  test "Readability fixture ebb-org" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
