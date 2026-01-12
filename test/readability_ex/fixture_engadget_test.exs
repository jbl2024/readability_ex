defmodule ReadabilityEx.Fixture_engadgetTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "engadget"

  test "Readability fixture engadget" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
