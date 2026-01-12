defmodule ReadabilityEx.Fixture_thevergeTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "theverge"

  test "Readability fixture theverge" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
