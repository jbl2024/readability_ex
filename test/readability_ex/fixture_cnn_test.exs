defmodule ReadabilityEx.Fixture_cnnTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "cnn"

  test "Readability fixture cnn" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
