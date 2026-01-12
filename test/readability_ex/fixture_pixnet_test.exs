defmodule ReadabilityEx.Fixture_pixnetTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "pixnet"

  test "Readability fixture pixnet" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
