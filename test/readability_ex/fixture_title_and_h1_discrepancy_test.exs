defmodule ReadabilityEx.Fixture_title_and_h1_discrepancyTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "title-and-h1-discrepancy"

  test "Readability fixture title-and-h1-discrepancy" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
