defmodule ReadabilityEx.Fixture_mathjaxTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "mathjax"

  test "Readability fixture mathjax" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
