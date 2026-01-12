defmodule ReadabilityEx.Fixture_la_nacionTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "la-nacion"

  test "Readability fixture la-nacion" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
