defmodule ReadabilityEx.Fixture_hidden_nodesTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "hidden-nodes"

  test "Readability fixture hidden-nodes" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
