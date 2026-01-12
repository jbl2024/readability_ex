defmodule ReadabilityEx.Fixture_cnetTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "cnet"

  test "Readability fixture cnet" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
