defmodule ReadabilityEx.Fixture_aktualneTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "aktualne"

  test "Readability fixture aktualne" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
