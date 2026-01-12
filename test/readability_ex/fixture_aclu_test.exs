defmodule ReadabilityEx.Fixture_acluTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "aclu"

  test "Readability fixture aclu" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
